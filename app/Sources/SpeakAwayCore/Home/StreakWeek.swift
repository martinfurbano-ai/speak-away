import Foundation

/// One dot of the week strip on the home screen.
public struct StreakDay: Equatable, Identifiable, Sendable {
    public let day: DayKey
    /// 0 for Monday through 6 for Sunday.
    public let index: Int
    /// Something was dictated that day.
    public let done: Bool
    public let isToday: Bool
    public let isFuture: Bool

    public var id: Int { day.ordinal }
}

public enum StreakWeek {
    /// Monday to Sunday of the week that holds `today`.
    public static func days(containing today: DayKey, stats: UsageStats) -> [StreakDay] {
        let monday = today.mondayOfWeek
        return (0..<7).map { i in
            let day = monday.adding(i)
            return StreakDay(day: day, index: i, done: stats.days[day.ordinal] != nil,
                             isToday: day == today, isFuture: day > today)
        }
    }
}

/// The line under the streak number.
public enum StreakNote: Equatable, Sendable {
    /// No streak yet.
    case start
    /// A streak that today's dictation keeps alive.
    case keep
    /// Today is done and an older streak was longer.
    case best(Int)
    /// Today is done and this is the longest streak so far.
    case record

    public static func make(streak: Int, dictatedToday: Bool, best: Int) -> StreakNote {
        if streak == 0 { return .start }
        if !dictatedToday { return .keep }
        return best > streak ? .best(best) : .record
    }
}
