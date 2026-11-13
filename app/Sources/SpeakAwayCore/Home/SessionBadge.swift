import Foundation

/// What the session card on the home screen says: the little pill next to the Start / End button.
public enum SessionBadge: Equatable, Sendable {
    /// No session: grey dot, "Session off".
    case off
    /// The mic is ready in the background; `minutesLeft` is `nil` when the session lasts until the user ends it.
    case ready(minutesLeft: Int?)
    /// A dictation is being recorded right now.
    case listening
    /// The dictation was recorded and is being written.
    case writing
    /// The last dictation failed.
    case problem

    /// `sessionEnd` comes from the app's own session controller, not from the published state: the state
    /// the keyboard reads only says "ready", the controller knows when the time is up.
    public static func make(state: SessionState, sessionEnd: Date?, active: Bool, now: Date) -> SessionBadge {
        guard active else { return .off }
        switch state {
        case .recording: return .listening
        case .transcribing: return .writing
        case .failed: return .problem
        case .idle, .ready, .done: return .ready(minutesLeft: minutesLeft(until: sessionEnd, now: now))
        }
    }

    /// To the nearest minute and never zero: a session that is still running always has "1 min" left.
    private static func minutesLeft(until end: Date?, now: Date) -> Int? {
        guard let end else { return nil }
        return max(1, Int((end.timeIntervalSince(now) / 60).rounded()))
    }
}
