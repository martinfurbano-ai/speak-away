import Foundation

/// Who holds the microphone. There is one owner at a time: a dictation session for the keyboard, or a meeting.
public enum MicOwner: Equatable, Sendable {
    case nobody
    case dictation
    case meeting

    /// `meetingActive` is true for a paused meeting too: it is not over, and the dictation has to wait.
    public static func current(dictationSessionLive: Bool, meetingActive: Bool) -> MicOwner {
        if meetingActive { return .meeting }
        return dictationSessionLive ? .dictation : .nobody
    }
}

/// What wants the microphone.
public enum MicUse: Equatable, Sendable {
    case dictation
    case meeting
}

/// The one rule about the microphone, pure so the app only carries out the answer:
/// a meeting takes the microphone from a dictation session (ending it cleanly), and a dictation
/// never takes it from a meeting.
public enum MicArbiter {
    public enum Decision: Equatable, Sendable {
        /// Go ahead.
        case grant
        /// End the dictation session first, then go ahead.
        case endDictationFirst
        case refuse(Refusal)
    }

    public enum Refusal: Equatable, Sendable {
        /// A meeting is already being recorded.
        case meetingAlreadyRecording
        /// A dictation cannot start while a meeting is being recorded.
        case meetingInProgress
    }

    public static func decide(_ use: MicUse, owner: MicOwner) -> Decision {
        switch (use, owner) {
        case (.meeting, .nobody): return .grant
        case (.meeting, .dictation): return .endDictationFirst
        case (.meeting, .meeting): return .refuse(.meetingAlreadyRecording)
        case (.dictation, .nobody), (.dictation, .dictation): return .grant
        case (.dictation, .meeting): return .refuse(.meetingInProgress)
        }
    }
}
