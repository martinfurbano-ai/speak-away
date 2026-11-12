import Foundation

/// What the app does with a request from the keyboard, given what it is doing now. Pure: the app
/// only carries out the answer. A request that does not fit the moment is ignored, never queued,
/// so a double tap or a late message cannot start a second recording.
public enum SessionDispatch {
    public enum Intent: Equatable, Sendable {
        case beginDictation
        /// Record an instruction for the keyboard's text `on`.
        case beginCommand(on: String)
        /// Stop recording and transcribe.
        case finish
        /// Drop the recording.
        case cancel
        /// Apply an instruction that is already written, without recording.
        case runCommand(instruction: String, on: String)
        case ignore
    }

    public static func intent(for message: SessionMessage, in state: SessionState) -> Intent {
        switch message {
        case .start:
            return isFree(state) ? .beginDictation : .ignore
        case .startCommand(let target):
            return isFree(state) ? .beginCommand(on: target) : .ignore
        case .stop:
            return isRecording(state) ? .finish : .ignore
        case .cancel:
            return isRecording(state) ? .cancel : .ignore
        case .command(let instruction, let target):
            return isFree(state) ? .runCommand(instruction: instruction, on: target) : .ignore
        }
    }

    /// A live session that is not busy. A published failure counts: the session is still running.
    private static func isFree(_ state: SessionState) -> Bool {
        switch state {
        case .ready, .done, .failed: return true
        case .idle, .recording, .transcribing: return false
        }
    }

    private static func isRecording(_ state: SessionState) -> Bool {
        if case .recording = state { return true }
        return false
    }
}
