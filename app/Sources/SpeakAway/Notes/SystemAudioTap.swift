import AVFoundation
import CoreAudio
import CoreMedia
import ScreenCaptureKit

/// The "Them" track: whatever the other apps play, which in a call is the other people's voices.
/// No bot, no virtual audio driver. Output is 16 kHz mono Float, delivered on a background queue.
///
/// Two ways in, tried in this order:
///
/// 1. Core Audio process tap (macOS 14.4+): `CATapDescription` + `AudioHardwareCreateProcessTap` + a private
///    aggregate device that reads the tap. Audio only, no screen involved.
///    Permission: "System Audio Recording Only" (TCC service kTCCServiceAudioCapture). macOS shows the prompt the
///    first time the tap starts, with the text of `NSAudioCaptureUsageDescription` from Info.plist (the key MUST be
///    there or the prompt cannot be shown). There is no public API to ask whether the permission was granted. When
///    it was denied, the tap still starts and delivers buffers that are all exact zeros; that is why MeetingRecorder
///    reports `.noSoundYet` when the track has no sound after a while.
///    Sandbox: the tap, the private aggregate device and the IO proc work inside the App Sandbox without an extra
///    entitlement (audio-input is not even needed for the tap itself); the only requirement is the Info.plist key.
///    Not verified on a signed sandboxed build from this environment.
///
/// 2. ScreenCaptureKit audio-only (macOS 13+, so it covers 14.0 to 14.3): an `SCStream` on the main display with
///    `capturesAudio` and `excludesCurrentProcessAudio`, video reduced to a 2x2 image at 1 fps and ignored.
///    Permission: "Screen & System Audio Recording" (kTCCServiceScreenCapture). The prompt appears on the first
///    `SCShareableContent` call, and macOS 15 and later re-asks about once a month. Info.plist needs no key for it
///    and the sandbox needs no extra entitlement. If denied, `start()` throws and the recorder keeps the mic track.
///
/// Our own process is excluded in both paths, so the app's own sounds never end up in the transcript.
final class SystemAudioTap: NSObject {
    enum Backend: String, Sendable { case coreAudioTap, screenCaptureKit }

    enum Failure: LocalizedError {
        case tap(String, OSStatus)
        case noDisplay
        var errorDescription: String? {
            switch self {
            case let .tap(step, status): return "No se pudo capturar el audio del sistema (\(step), código \(status))."
            case .noDisplay: return "No hay pantalla para capturar el audio del sistema."
            }
        }
    }

    private let onSamples: @Sendable ([Float]) -> Void
    private(set) var backend: Backend?
    private var processTap: AnyObject?
    private var screenStream: SCStream?
    private let screenQueue = DispatchQueue(label: "speakaway.screen-audio", qos: .userInitiated)
    private let screenResampler = AudioResampler()

    init(onSamples: @escaping @Sendable ([Float]) -> Void) {
        self.onSamples = onSamples
    }

    func start() async throws {
        if #available(macOS 14.4, *) {
            let tap = ProcessTap(onSamples: onSamples)
            do {
                try tap.start()
                processTap = tap
                backend = .coreAudioTap
                return
            } catch {
                tap.stop() // fall through to ScreenCaptureKit
            }
        }
        try await startScreenCaptureKit()
        backend = .screenCaptureKit
    }

    func stop() {
        if #available(macOS 14.4, *) { (processTap as? ProcessTap)?.stop() }
        processTap = nil
        if let stream = screenStream {
            screenStream = nil
            Task { try? await stream.stopCapture() }
        }
        backend = nil
    }

    // MARK: ScreenCaptureKit

    private func startScreenCaptureKit() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else { throw Failure.noDisplay }
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48_000
        config.channelCount = 2
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        let stream = SCStream(filter: SCContentFilter(display: display, excludingWindows: []), configuration: config, delegate: nil)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: screenQueue)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: screenQueue) // swallowed, avoids "no output" log spam
        try await stream.startCapture()
        screenStream = stream
    }
}

extension SystemAudioTap: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid, let buffer = Self.pcmBuffer(from: sampleBuffer) else { return }
        let samples = screenResampler.convert(buffer)
        if !samples.isEmpty { onSamples(samples) }
    }

    private static func pcmBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard
            let description = CMSampleBufferGetFormatDescription(sampleBuffer),
            var asbd = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee,
            let format = AVAudioFormat(streamDescription: &asbd)
        else { return nil }
        let frames = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(sampleBuffer, at: 0, frameCount: Int32(frames), into: buffer.mutableAudioBufferList)
        return status == noErr ? buffer : nil
    }
}

// MARK: Core Audio process tap

@available(macOS 14.4, *)
private final class ProcessTap {
    private let onSamples: @Sendable ([Float]) -> Void
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private let queue = DispatchQueue(label: "speakaway.process-tap", qos: .userInitiated)
    private let resampler = AudioResampler()

    init(onSamples: @escaping @Sendable ([Float]) -> Void) {
        self.onSamples = onSamples
    }

    func start() throws {
        let excluded = Self.processObject(pid: getpid()).map { [$0] } ?? []
        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: excluded)
        description.uuid = UUID()
        description.name = "Speak Away"
        description.isPrivate = true

        var status = AudioHardwareCreateProcessTap(description, &tapID)
        guard status == noErr else { throw SystemAudioTap.Failure.tap("create tap", status) }

        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var formatAddress = AudioObjectPropertyAddress(mSelector: kAudioTapPropertyFormat, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        status = AudioObjectGetPropertyData(tapID, &formatAddress, 0, nil, &size, &format)
        guard status == noErr, let tapFormat = AVAudioFormat(streamDescription: &format) else { throw SystemAudioTap.Failure.tap("tap format", status) }

        guard let outputUID = Self.defaultOutputUID() else { throw SystemAudioTap.Failure.tap("default output", -1) }
        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Speak Away Tap",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapDriftCompensationKey: true,
                kAudioSubTapUIDKey: description.uuid.uuidString,
            ]],
        ]
        status = AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID)
        guard status == noErr else { throw SystemAudioTap.Failure.tap("create aggregate device", status) }

        let resampler = self.resampler
        let sink = onSamples
        status = AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, queue) { _, inputData, _, _, _ in
            guard let buffer = AVAudioPCMBuffer(pcmFormat: tapFormat, bufferListNoCopy: inputData, deallocator: nil) else { return }
            let samples = resampler.convert(buffer)
            if !samples.isEmpty { sink(samples) }
        }
        guard status == noErr, let procID else { throw SystemAudioTap.Failure.tap("create IO proc", status) }
        status = AudioDeviceStart(aggregateID, procID)
        guard status == noErr else { throw SystemAudioTap.Failure.tap("start device", status) }
    }

    func stop() {
        if aggregateID != kAudioObjectUnknown {
            if let procID {
                AudioDeviceStop(aggregateID, procID)
                AudioDeviceDestroyIOProcID(aggregateID, procID)
            }
            AudioHardwareDestroyAggregateDevice(aggregateID)
        }
        if tapID != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tapID) }
        procID = nil
        aggregateID = AudioObjectID(kAudioObjectUnknown)
        tapID = AudioObjectID(kAudioObjectUnknown)
    }

    private static func processObject(pid: pid_t) -> AudioObjectID? {
        var pid = pid
        var object = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, UInt32(MemoryLayout<pid_t>.size), &pid, &size, &object)
        return status == noErr && object != kAudioObjectUnknown ? object : nil
    }

    private static func defaultOutputUID() -> String? {
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr else { return nil }
        var uid: Unmanaged<CFString>?
        size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceUID, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &uid) == noErr, let uid else { return nil }
        return uid.takeRetainedValue() as String
    }
}
