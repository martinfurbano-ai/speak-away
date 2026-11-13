import AVFoundation

/// The microphone. It stays running for the whole session so the app keeps running in the background;
/// what it hears is handed over without being kept. The session mixes with other audio, so the user's
/// music keeps playing.
final class MicInput: AudioInput {
    let needsMicrophone = true
    var onEvent: ((AudioInputEvent) -> Void)?
    var preferredInputUID = ""

    private let engine = AVAudioEngine()
    private var onBuffer: ((AVAudioPCMBuffer) -> Void)?
    private var observers: [NSObjectProtocol] = []
    private var running = false

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
        self.onBuffer = onBuffer
        try startEngine()
        running = true
        observe()
    }

    func stop() {
        guard running else { return }
        running = false
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        onBuffer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Input choice

    /// The microphone picked in Settings, when it is still connected; otherwise the system keeps choosing.
    private func choosePreferredInput(on session: AVAudioSession) {
        let wanted = MicrophoneChoices.availableInput(uid: preferredInputUID, in: session.availableInputs ?? [])
        try? session.setPreferredInput(wanted)
    }

    // MARK: Engine

    private func startEngine() throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw AudioInputError.noMicrophone }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.onBuffer?(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw AudioInputError.cannotStart(error.localizedDescription)
        }
    }

    private func observe() {
        let center = NotificationCenter.default
        // A new route (AirPods connected, headphones unplugged) stops the engine: start it again on the new format.
        observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            guard let self, self.running else { return }
            do { try self.startEngine() } catch { self.fail(error) }
        })
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard let self, self.running,
                  let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
            self.onEvent?(.interrupted)
        })
    }

    private func fail(_ error: Error) {
        onEvent?(.failed(error))
    }

    private static func hasPermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return true
        case .denied: return false
        default: return await AVAudioApplication.requestRecordPermission()
        }
    }
}
