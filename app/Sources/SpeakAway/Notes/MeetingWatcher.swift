import AppKit
import CoreAudio
import SpeakAwayCore

/// Notices when a call starts so the UI can ask "¿Tomar notas?" once, and when it ends.
///
/// Every 5 s it reads three cheap things: which apps run (NSWorkspace), whether the default input device is
/// running for someone (`kAudioDevicePropertyDeviceIsRunningSomewhere`), and, on macOS 14.2+, which processes
/// hold an input stream (`kAudioHardwarePropertyProcessObjectList`, `kAudioProcessPropertyIsRunningInput`, bundle
/// ID). `MeetingDetector` turns that into a meeting app and `MeetingPresence` removes flicker.
/// All of it is read-only and works inside the App Sandbox with no permission prompt.
///
/// Our own use of the mic never counts: the process list drops our bundle ID, and while `isBusy` says we are
/// dictating or recording, the "device is in use" fallback is ignored.
@MainActor
final class MeetingWatcher {
    var onMeetingStarted: ((MeetingApp) -> Void)?
    var onMeetingEnded: (() -> Void)?
    /// True while Speak Away itself holds the microphone (dictating or recording a meeting).
    var isBusy: () -> Bool = { false }

    private(set) var current: MeetingApp?
    private var presence = MeetingPresence()
    private var timer: Timer?
    static let interval: TimeInterval = 5

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        timer?.tolerance = 1
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        presence = MeetingPresence()
        current = nil
    }

    /// One reading. Exposed for tests and for the UI to force a check.
    func poll() {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let users = Self.micUsers()
        let busy = isBusy()
        let micInUse = !busy && Self.defaultInputIsRunning()
        let app = MeetingDetector.detect(running: running, micUsers: users, micInUse: micInUse)
        let (next, event) = presence.observing(app)
        presence = next
        switch event {
        case let .started(app):
            current = app
            onMeetingStarted?(app)
        case .ended:
            current = nil
            onMeetingEnded?()
        case nil:
            break
        }
    }

    // MARK: Core Audio reads

    static func defaultInputIsRunning() -> Bool {
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr, device != kAudioObjectUnknown else { return false }
        var running: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        return AudioObjectGetPropertyData(device, &address, 0, nil, &size, &running) == noErr && running != 0
    }

    /// Bundle IDs of processes with an active input stream. Empty if the system cannot say (before 14.2) or nobody has one.
    static func micUsers() -> Set<String> {
        guard #available(macOS 14.2, *) else { return [] }
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyProcessObjectList, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var objects = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &objects) == noErr else { return [] }
        var ids = Set<String>()
        for object in objects {
            var input: UInt32 = 0
            var inputSize = UInt32(MemoryLayout<UInt32>.size)
            var inputAddress = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyIsRunningInput, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            guard AudioObjectGetPropertyData(object, &inputAddress, 0, nil, &inputSize, &input) == noErr, input != 0 else { continue }
            var bundle: Unmanaged<CFString>?
            var bundleSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            var bundleAddress = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyBundleID, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            guard AudioObjectGetPropertyData(object, &bundleAddress, 0, nil, &bundleSize, &bundle) == noErr, let bundle else { continue }
            ids.insert(bundle.takeRetainedValue() as String)
        }
        return ids
    }
}
