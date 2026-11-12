import Foundation

/// How long the mic stays ready in the background after the user starts a session.
public enum SessionLength: String, Codable, CaseIterable, Sendable {
    case fiveMinutes, fifteenMinutes, oneHour, untilStopped

    /// Seconds, or `nil` when the session only ends when the user stops it.
    public var duration: TimeInterval? {
        switch self {
        case .fiveMinutes: return 5 * 60
        case .fifteenMinutes: return 15 * 60
        case .oneHour: return 60 * 60
        case .untilStopped: return nil
        }
    }

    public var title: String {
        switch self {
        case .fiveMinutes: return "5 minutes"
        case .fifteenMinutes: return "15 minutes"
        case .oneHour: return "1 hour"
        case .untilStopped: return "Until I stop it"
        }
    }
}

/// The session length the user picked and what follows from it. All functions return new values.
public struct SessionPolicy: Equatable, Codable, Sendable {
    public let length: SessionLength

    public init(length: SessionLength = .fifteenMinutes) {
        self.length = length
    }

    /// When a session that starts at `start` ends. `nil`: never.
    public func expiry(from start: Date) -> Date? {
        length.duration.map { start.addingTimeInterval($0) }
    }

    /// The state the app publishes the moment the session starts.
    public func startedState(at start: Date) -> SessionState {
        .ready(until: expiry(from: start))
    }

    /// Seconds left until `until`, never below 0. `nil` when the session has no end.
    public static func remaining(until: Date?, at now: Date) -> TimeInterval? {
        until.map { max(0, $0.timeIntervalSince(now)) }
    }

    public static func isExpired(until: Date?, at now: Date) -> Bool {
        guard let until else { return false }
        return now >= until
    }

    /// A state read from the shared file may be older than the app (killed, or the time ran out
    /// while the keyboard was away): a `ready` state past its end reads as `idle`. Anything else is kept.
    public static func reconciled(_ state: SessionState, at now: Date) -> SessionState {
        guard case .ready(let until) = state, isExpired(until: until, at: now) else { return state }
        return .idle
    }
}
