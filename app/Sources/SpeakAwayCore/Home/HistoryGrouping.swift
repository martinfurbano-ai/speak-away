import Foundation

public enum HistoryDayLabel: Equatable, Hashable, Sendable {
    case today
    case yesterday
    /// Any other day, as the start of that day.
    case date(Date)
}

public struct HistoryDayGroup: Equatable, Identifiable, Sendable {
    public let label: HistoryDayLabel
    public let day: DayKey
    /// Newest first.
    public let items: [HistoryItem]

    public var id: Int { day.ordinal }
}

public enum HistoryGrouping {
    /// One group per calendar day, the newest day first and the newest dictation first inside it.
    /// Dictations with the same time keep the order they came in.
    public static func byDay(_ items: [HistoryItem], now: Date = Date(), calendar: Calendar = .current) -> [HistoryDayGroup] {
        let today = DayKey(now, calendar: calendar)
        let newestFirst = items.enumerated()
            .sorted { a, b in a.element.date != b.element.date ? a.element.date > b.element.date : a.offset < b.offset }
            .map(\.element)
        let grouped = Dictionary(grouping: newestFirst) { DayKey($0.date, calendar: calendar) }
        return grouped.keys.sorted(by: >).map { day in
            let inDay = grouped[day] ?? []
            return HistoryDayGroup(label: label(for: day, today: today, sample: inDay.first?.date, calendar: calendar),
                                   day: day, items: inDay)
        }
    }

    private static func label(for day: DayKey, today: DayKey, sample: Date?, calendar: Calendar) -> HistoryDayLabel {
        if day == today { return .today }
        if day == today.adding(-1) { return .yesterday }
        return .date(calendar.startOfDay(for: sample ?? Date()))
    }
}
