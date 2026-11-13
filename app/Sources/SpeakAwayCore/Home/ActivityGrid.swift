import Foundation

/// One square of the activity map.
public struct ActivityCell: Equatable, Identifiable, Sendable {
    public let day: DayKey
    public let words: Int
    /// 0 for an empty day, otherwise from 0.3 up to 1 relative to the busiest day shown.
    public let level: Double
    public let isFuture: Bool

    public var id: Int { day.ordinal }
}

/// The last weeks of activity as columns, the way the home screen draws them.
public struct ActivityGrid: Equatable, Sendable {
    /// Oldest week first. Every column has seven cells, Monday to Sunday.
    public let weeks: [[ActivityCell]]

    /// The week that holds `today` is the last column, so the days after today are the future.
    public static func make(stats: UsageStats, today: DayKey, weeks requested: Int = 16) -> ActivityGrid {
        let count = max(1, requested)
        let first = today.mondayOfWeek.adding(-(count - 1) * 7)
        let raw: [[(day: DayKey, words: Int)]] = (0..<count).map { w in
            (0..<7).map { d in
                let day = first.adding(w * 7 + d)
                return (day, day > today ? 0 : stats.days[day.ordinal]?.words ?? 0)
            }
        }
        let top = max(1, raw.joined().map(\.words).max() ?? 1)
        let columns = raw.map { column in
            column.map { entry in
                ActivityCell(day: entry.day, words: entry.words,
                             level: entry.words == 0 ? 0 : 0.3 + 0.7 * Double(entry.words) / Double(top),
                             isFuture: entry.day > today)
            }
        }
        return ActivityGrid(weeks: columns)
    }
}
