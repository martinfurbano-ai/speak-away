import Foundation

/// What the app's once-a-second clock does for a live session. Pure, so the timing is tested without waiting.
public enum SessionTick {
    /// How long a result (or a failure) stays published for the keyboard to take, before the app goes
    /// back to ready. Shorter than `SessionLiveness.staleAfter`, or the keyboard would read the session as gone.
    public static let resultHold: TimeInterval = 8

    public enum Action: Equatable, Sendable {
        case none
        /// Publish the same state again with a fresh time, so the keyboard knows the app is alive.
        case heartbeat
        /// The result was held long enough: publish ready again.
        case settle
        /// The session ran out of time: stop the mic and publish idle.
        case expire
    }

    /// `publishedAt` is when `state` was last written; `sessionEnd` is when the session ends (`nil`: never).
    public static func decide(state: SessionState, publishedAt: Date, sessionEnd: Date?, now: Date) -> Action {
        let age = now.timeIntervalSince(publishedAt)
        switch state {
        case .idle:
            return .none
        case .ready:
            if SessionPolicy.isExpired(until: sessionEnd, at: now) { return .expire }
            return age >= SessionLiveness.heartbeatInterval ? .heartbeat : .none
        case .recording, .transcribing:
            // A dictation in progress is finished first, even when the session time is up.
            return age >= SessionLiveness.heartbeatInterval ? .heartbeat : .none
        case .done, .failed:
            guard age >= resultHold else { return .none }
            return SessionPolicy.isExpired(until: sessionEnd, at: now) ? .expire : .settle
        }
    }
}
