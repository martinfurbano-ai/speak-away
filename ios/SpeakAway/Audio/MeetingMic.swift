import AVFoundation

/// The microphone of a meeting. Unlike the dictation session's, it really stops when the meeting is paused (so the
/// system's recording indicator goes off) and it reports calls and route changes instead of ending. What it hears
/// is handed over and never kept.
final class MeetingMic {
    enum Event {
        /// A call, Siri, an alarm or another app took the microphone. The engine has already stopped.
        case interruptionBegan
        /// The system gave the microphone back. `shouldResume` says the app may record again by itself.
        case interruptionEnded(shouldResume: Bool)
        /// The input is another microphone now (a headset plugged in or taken out).
        case inputChanged
        /// The engine could not be kept running.
        case failed(Error)
    }

    /// Called on the main queue.
    var onEvent: ((Event) -> Void)?
    /// The unique id of the input the user picked in Settings. Empty: the one the system picks. Set before `start`.
    var preferredInputUID = ""

    private let engine = AVAudioEngine()
    private var deliver: ((AVAudioPCMBuffer) -> Void)?
    private var observers: [NSObjectProtocol] = []
    private var lastInputUID: String?
    private var inUse = false
    private(set) var isCapturing = false

    // MARK: Start and stop

    /// Asks for permission when needed, takes the audio session and starts capturing. Buffers arrive on the audio thread.
    func start(onBuffer: @escaping (AVAudioPCMBuffer) -> Void) async throws {
        guard await Self.hasPermission() else { throw AudioInputError.microphoneDenied }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .allowBluetoothA2DP, .defaultToSpeaker])
            try session.setActive(true)
        } catch {
            throw AudioInputError.cannotStart(error.localizedDescription)
        }
        choosePreferredInput(on: session)
        deliver = onBuffer
        inUse = true
        do {
            try startEngine()
        } catch {
            stop()
            throw error
        }
        observe()
    }

    /// Stops capturing but keeps the session, so resuming is quick. The engine is off: nothing is heard.
    func pause() {
        stopEngine()
    }

    /// Starts capturing again after `pause()` or after the system took the microphone. Does nothing while capturing.
    func resume() throws {
        guard inUse, !isCapturing else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(true)
        } catch {
            throw AudioInputError.cannotStart(error.localizedDescription)
        }
        choosePreferredInput(on: session)
        try startEngine()
    }

    /// Stops and starts again on whatever input there is now, with its own format.
    func restart() throws {
        guard inUse else { return }
        stopEngine()
        try startEngine()
    }

    func stop() {
        guard inUse else { return }
        inUse = false
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
        stopEngine()
        deliver = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Engine

    private func startEngine() throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw AudioInputError.noMicrophone }
        input.removeTap(onBus: 0)
        // The callback owns its copy of the closure: the audio thread never reads this object's state.
        let deliver = self.deliver
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            deliver?(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw AudioInputError.cannotStart(error.localizedDescription)
        }
        isCapturing = true
        lastInputUID = Self.currentInputUID()
    }

    private func stopEngine() {
        guard isCapturing else { return }
        isCapturing = false
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    // MARK: Input choice

    /// The microphone picked in Settings, when it is still connected; otherwise the system keeps choosing.
    private func choosePreferredInput(on session: AVAudioSession) {
        let wanted = MicrophoneChoices.availableInput(uid: preferredInputUID, in: session.availableInputs ?? [])
        try? session.setPreferredInput(wanted)
    }

    private static func currentInputUID() -> String? {
        AVAudioSession.sharedInstance().currentRoute.inputs.first?.uid
    }

    // MARK: Notifications

    private func observe() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            self?.interruption(note)
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.routeChanged()
        })
        // The engine stops by itself when its input changes format or goes away.
        observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            self?.engineChanged()
        })
    }

    private func interruption(_ note: Notification) {
        guard inUse, let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        switch type {
        case .began:
            // The system already stopped the engine; keep our bookkeeping in step so `resume()` starts it again.
            if isCapturing {
                isCapturing = false
                engine.inputNode.removeTap(onBus: 0)
                engine.stop()
            }
            onEvent?(.interruptionBegan)
        case .ended:
            let options = AVAudioSession.InterruptionOptions(rawValue: note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
            onEvent?(.interruptionEnded(shouldResume: options.contains(.shouldResume)))
        @unknown default:
            break
        }
    }

    /// A different microphone is in use: tell the recorder, which marks it in the transcript and restarts capture.
    private func routeChanged() {
        guard inUse else { return }
        let now = Self.currentInputUID()
        guard isCapturing else {
            lastInputUID = now
            return
        }
        guard now != lastInputUID else { return }
        lastInputUID = now
        onEvent?(.inputChanged)
    }

    private func engineChanged() {
        guard inUse, isCapturing else { return }
        let now = Self.currentInputUID()
        if now != lastInputUID {
            lastInputUID = now
            onEvent?(.inputChanged)
            return
        }
        // Same microphone, new format (a Bluetooth route switching): start again without a word in the transcript.
        do { try restart() } catch { onEvent?(.failed(error)) }
    }

    private static func hasPermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return true
        case .denied: return false
        default: return await AVAudioApplication.requestRecordPermission()
        }
    }
}
