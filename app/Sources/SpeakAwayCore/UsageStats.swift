import Foundation

/// A calendar day in the user's time zone, as a day number so consecutive days differ by one.
public struct DayKey: Hashable, Comparable, Sendable {
    public let ordinal: Int

    public init(ordinal: Int) { self.ordinal = ordinal }

    public init(_ date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let midnight = utc.date(from: DateComponents(year: c.year, month: c.month, day: c.day))!
        ordinal = Int((midnight.timeIntervalSince1970 / 86_400).rounded())
    }

    public func adding(_ days: Int) -> DayKey { DayKey(ordinal: ordinal + days) }

    public static func < (a: DayKey, b: DayKey) -> Bool { a.ordinal < b.ordinal }
}

public struct DayStats: Codable, Equatable, Sendable {
    public let words: Int
    public let seconds: Double
    public let sessions: Int
}

/// What the home window shows: words, speed, time saved and streaks.
/// Only numbers per day are kept, never what was said.
public struct UsageStats: Codable, Equatable, Sendable {
    public let days: [Int: DayStats]

    public init(days: [Int: DayStats] = [:]) { self.days = days }

    public static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }

    public func recording(words: Int, seconds: Double, on day: DayKey) -> UsageStats {
        guard words > 0 else { return self }
        let old = days[day.ordinal] ?? DayStats(words: 0, seconds: 0, sessions: 0)
        let new = DayStats(words: old.words + words, seconds: old.seconds + max(0, seconds), sessions: old.sessions + 1)
        return UsageStats(days: days.merging([day.ordinal: new]) { _, n in n })
    }

    public var totalWords: Int { days.values.reduce(0) { $0 + $1.words } }
    public var totalSessions: Int { days.values.reduce(0) { $0 + $1.sessions } }
    public var totalSeconds: Double { days.values.reduce(0) { $0 + $1.seconds } }

    public var wordsPerMinute: Int {
        totalSeconds > 0 ? Int((Double(totalWords) / (totalSeconds / 60)).rounded()) : 0
    }

    /// Minutes it would have taken to type the same words, minus the minutes spent talking.
    public func minutesSaved(typingWPM: Double = 40) -> Int {
        max(0, Int((Double(totalWords) / typingWPM - totalSeconds / 60).rounded()))
    }

    /// Consecutive days with dictation, ending today or, if today has none yet, yesterday.
    public func currentStreak(today: DayKey) -> Int {
        var day = days[today.ordinal] != nil ? today : today.adding(-1)
        var count = 0
        while days[day.ordinal] != nil {
            count += 1
            day = day.adding(-1)
        }
        return count
    }

    public var bestStreak: Int {
        let sorted = days.keys.sorted()
        var best = 0, run = 0, previous: Int?
        for d in sorted {
            run = previous.map { d - $0 == 1 } == true ? run + 1 : 1
            best = max(best, run)
            previous = d
        }
        return best
    }

    /// Words per day for the last `days` days, oldest first.
    public func activity(endingOn end: DayKey, days count: Int) -> [Int] {
        (0..<count).map { i in days[end.adding(i - count + 1).ordinal]?.words ?? 0 }
    }
}

/// The next word count to celebrate.
public struct Milestone: Equatable, Sendable {
    public let previous: Int
    public let target: Int
    public let progress: Double

    static let steps = [1_000, 5_000, 10_000, 25_000, 50_000, 100_000, 250_000, 500_000, 1_000_000]

    public static func next(after words: Int) -> Milestone {
        var previous = 0
        var target = steps.first { $0 > words }
        if target == nil {
            target = steps.last! * 2
            while target! <= words { target! *= 2 }
            previous = target! / 2
        } else {
            previous = steps.last { $0 < target! } ?? 0
        }
        let span = Double(target! - previous)
        return Milestone(previous: previous, target: target!, progress: min(1, max(0, Double(words - previous) / span)))
    }
}
