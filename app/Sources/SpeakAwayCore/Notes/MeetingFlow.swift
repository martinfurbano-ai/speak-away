import Foundation

/// A note about the recording itself, written into the transcript at the moment it happened.
public enum MeetingMarker: Equatable, Sendable {
    case paused
    case resumed
    /// A phone call, Siri or an alarm took the microphone.
    case interrupted
    case microphoneChanged
    /// The app was closed or the phone restarted before the meeting was stopped.
    case endedUnexpectedly

    public func text(english: Bool) -> String {
        switch self {
        case .paused: return english ? "Paused" : "Pausa"
        case .resumed: return english ? "Recording resumed" : "Se reanudó la grabación"
        case .interrupted: return english ? "Paused by a call or another app" : "Pausa por una llamada o por otra app"
        case .microphoneChanged: return english ? "Microphone changed" : "Cambió el micrófono"
        case .endedUnexpectedly:
            return english ? "The recording was cut off before it finished" : "La grabación se cortó antes de terminar"
        }
    }
}

/// Why a meeting is waiting.
public enum PauseCause: Equatable, Sendable {
    /// The user pressed Pause.
    case user
    /// The system took the microphone (a call, Siri, an alarm). The meeting resumes by itself when it can.
    case interruption
}

public enum MeetingPhase: Equatable, Sendable {
    case idle
    case recording
    case paused(PauseCause)
}

/// Something that happened to the meeting.
public enum MeetingEvent: Equatable, Sendable {
    case startRequested
    case pauseRequested
    case resumeRequested
    case stopRequested
    case interruptionBegan
    /// `shouldResume`: the system says the app may start recording again.
    case interruptionEnded(shouldResume: Bool)
    /// AirPods connected or disconnected, or the system changed the input.
    case microphoneChanged
    /// The engine could not keep or restart the microphone.
    case captureFailed
}

/// What the recorder has to do about it, in order.
public enum MeetingEffect: Equatable, Sendable {
    /// Start capturing (or start again after a pause).
    case beginCapture
    /// Stop capturing but keep the meeting.
    case suspendCapture
    /// Stop and start capturing on the new input.
    case restartCapture
    case mark(MeetingMarker)
    /// Close the meeting: finish the transcription, save, summarize.
    case finish
}

public struct MeetingStep: Equatable, Sendable {
    public let phase: MeetingPhase
    public let effects: [MeetingEffect]

    public init(phase: MeetingPhase, effects: [MeetingEffect]) {
        self.phase = phase
        self.effects = effects
    }
}

/// The meeting recorder's decisions, pure so a phone call or an AirPods change can be tested without a phone.
/// Anything that does not fit the moment changes nothing: a repeated event is never a second pause or a second start.
public enum MeetingFlow {
    public static func step(_ phase: MeetingPhase, _ event: MeetingEvent) -> MeetingStep {
        let unchanged = MeetingStep(phase: phase, effects: [])
        switch phase {
        case .idle:
            return event == .startRequested ? MeetingStep(phase: .recording, effects: [.beginCapture]) : unchanged

        case .recording:
            switch event {
            case .pauseRequested:
                return MeetingStep(phase: .paused(.user), effects: [.suspendCapture, .mark(.paused)])
            case .stopRequested:
                return MeetingStep(phase: .idle, effects: [.finish])
            case .interruptionBegan, .captureFailed:
                // A microphone that cannot be kept pauses the meeting, so what was said is safe and the user can resume.
                return MeetingStep(phase: .paused(.interruption), effects: [.suspendCapture, .mark(.interrupted)])
            case .microphoneChanged:
                return MeetingStep(phase: .recording, effects: [.restartCapture, .mark(.microphoneChanged)])
            case .startRequested, .resumeRequested, .interruptionEnded:
                return unchanged
            }

        case .paused(let cause):
            switch event {
            case .resumeRequested:
                return resume()
            case .interruptionEnded(let shouldResume):
                return cause == .interruption && shouldResume ? resume() : unchanged
            case .stopRequested:
                return MeetingStep(phase: .idle, effects: [.finish])
            case .startRequested, .pauseRequested, .interruptionBegan, .microphoneChanged, .captureFailed:
                return unchanged
            }
        }
    }

    private static func resume() -> MeetingStep {
        MeetingStep(phase: .recording, effects: [.beginCapture, .mark(.resumed)])
    }
}
