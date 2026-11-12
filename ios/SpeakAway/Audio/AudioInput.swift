import AVFoundation

/// Where the session's audio comes from: the microphone, or a file when the app checks itself.
protocol AudioInput: AnyObject {
    /// `true` when the system asks the user for permission before this input can run.
    var needsMicrophone: Bool { get }
    /// Told when the input stops by itself (a call, another app taking the mic) or fails.
    var onEvent: ((AudioInputEvent) -> Void)? { get set }
    /// Starts delivering buffers (on any thread) until `stop()`.
    func start(onBuffer: @escaping (AVAudioPCMBuffer) -> Void) async throws
    func stop()
}

enum AudioInputEvent {
    /// Something else took the microphone. The input has stopped.
    case interrupted
    case failed(Error)
}

enum AudioInputError: Error, Equatable {
    case microphoneDenied
    case noMicrophone
    case cannotStart(String)
}
