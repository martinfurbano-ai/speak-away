import Foundation

/// The meeting's time. `elapsed` is what the screen counts (the time spent recording); `offset` is where a
/// line belongs on the meeting's timeline (pauses included), like the times in the note.
/// Every change returns a new clock.
public struct MeetingClock: Equatable, Sendable {
    public let startedAt: Date
    private let pausedTotal: TimeInterval
    private let pausedAt: Date?

    public init(startedAt: Date) {
        self.init(startedAt: startedAt, pausedTotal: 0, pausedAt: nil)
    }

    private init(startedAt: Date, pausedTotal: TimeInterval, pausedAt: Date?) {
        self.startedAt = startedAt
        self.pausedTotal = pausedTotal
        self.pausedAt = pausedAt
    }

    public var isPaused: Bool { pausedAt != nil }

    /// Pausing a paused clock keeps the first pause.
    public func paused(at time: Date) -> MeetingClock {
        guard pausedAt == nil else { return self }
        return MeetingClock(startedAt: startedAt, pausedTotal: pausedTotal, pausedAt: time)
    }

    /// Resuming a clock that is not paused changes nothing.
    public func resumed(at time: Date) -> MeetingClock {
        guard let pausedAt else { return self }
        let waited = max(0, time.timeIntervalSince(pausedAt))
        return MeetingClock(startedAt: startedAt, pausedTotal: pausedTotal + waited, pausedAt: nil)
    }

    /// Seconds spent recording: the time since the start, without the pauses. It stands still while paused.
    public func elapsed(at now: Date) -> TimeInterval {
        let end = pausedAt ?? now
        return max(0, end.timeIntervalSince(startedAt) - pausedTotal)
    }

    /// Seconds since the meeting began, pauses included.
    public func offset(at now: Date) -> TimeInterval {
        max(0, now.timeIntervalSince(startedAt))
    }
}

/// The counter on the recording screen: `0:07`, `12:34`, `1:02:03`.
public enum ElapsedFormat {
    public static func string(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds)
        let hours = total / 3600, minutes = (total % 3600) / 60, secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }
}
