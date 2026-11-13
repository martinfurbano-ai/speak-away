import XCTest
@testable import SpeakAwayCore

final class WeekAndActivityTests: XCTestCase {
    private let panama: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Panama")!
        return c
    }()

    private func day(_ y: Int, _ m: Int, _ d: Int) -> DayKey {
        DayKey(panama.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!, calendar: panama)
    }

    /// Thursday 12 November 2026.
    private var today: DayKey { day(2026, 11, 12) }

    private func stats(_ words: [DayKey: Int]) -> UsageStats {
        UsageStats(days: Dictionary(uniqueKeysWithValues: words.map {
            ($0.key.ordinal, DayStats(words: $0.value, seconds: Double($0.value), sessions: 1))
        }))
    }

    // MARK: Weekday of a day

    func testWeekdayIndexStartsOnMonday() {
        XCTAssertEqual(day(2026, 11, 9).weekdayIndex, 0, "Monday")
        XCTAssertEqual(day(2026, 11, 12).weekdayIndex, 3, "Thursday")
        XCTAssertEqual(day(2026, 11, 15).weekdayIndex, 6, "Sunday")
        XCTAssertEqual(DayKey(ordinal: 0).weekdayIndex, 3, "1 January 1970 was a Thursday")
        XCTAssertEqual(DayKey(ordinal: -1).weekdayIndex, 2, "and the day before a Wednesday")
    }

    func testMondayAndSundayOfTheWeek() {
        XCTAssertEqual(today.mondayOfWeek, day(2026, 11, 9))
        XCTAssertEqual(today.sundayOfWeek, day(2026, 11, 15))
        XCTAssertEqual(day(2026, 11, 9).mondayOfWeek, day(2026, 11, 9))
        XCTAssertEqual(day(2026, 11, 15).mondayOfWeek, day(2026, 11, 9))
    }

    // MARK: The week strip

    func testTheStripHasSevenDaysFromMondayToSunday() {
        let week = StreakWeek.days(containing: today, stats: UsageStats())
        XCTAssertEqual(week.map(\.index), [0, 1, 2, 3, 4, 5, 6])
        XCTAssertEqual(week.first?.day, day(2026, 11, 9))
        XCTAssertEqual(week.last?.day, day(2026, 11, 15))
    }

    func testTheStripMarksDoneTodayAndFutureDays() {
        let s = stats([day(2026, 11, 9): 40, day(2026, 11, 10): 5, day(2026, 11, 12): 12, day(2026, 11, 1): 99])
        let week = StreakWeek.days(containing: today, stats: s)
        XCTAssertEqual(week.map(\.done), [true, true, false, true, false, false, false])
        XCTAssertEqual(week.filter(\.isToday).map(\.index), [3])
        XCTAssertEqual(week.map(\.isFuture), [false, false, false, false, true, true, true])
    }

    // MARK: Streak note

    func testStreakNote() {
        XCTAssertEqual(StreakNote.make(streak: 0, dictatedToday: false, best: 4), .start)
        XCTAssertEqual(StreakNote.make(streak: 3, dictatedToday: false, best: 3), .keep)
        XCTAssertEqual(StreakNote.make(streak: 3, dictatedToday: true, best: 9), .best(9))
        XCTAssertEqual(StreakNote.make(streak: 6, dictatedToday: true, best: 6), .record)
    }

    // MARK: The activity grid

    func testTheGridHasSixteenWeeksOfSevenDays() {
        let grid = ActivityGrid.make(stats: UsageStats(), today: today)
        XCTAssertEqual(grid.weeks.count, 16)
        XCTAssertTrue(grid.weeks.allSatisfy { $0.count == 7 })
    }

    func testTheLastColumnIsThisWeekAndTheFirstIsFifteenWeeksBack() {
        let grid = ActivityGrid.make(stats: UsageStats(), today: today)
        XCTAssertEqual(grid.weeks.last?.last?.day, day(2026, 11, 15), "ends on this week's Sunday")
        XCTAssertEqual(grid.weeks.first?.first?.day, day(2026, 11, 9).adding(-15 * 7), "starts on a Monday")
        XCTAssertEqual(grid.weeks.first?.first?.day.weekdayIndex, 0)
    }

    func testDaysRunOneAfterTheOther() {
        let days = ActivityGrid.make(stats: UsageStats(), today: today).weeks.flatMap { $0 }.map(\.day.ordinal)
        XCTAssertEqual(days, Array(days[0]..<(days[0] + 16 * 7)))
    }

    func testOnlyTheDaysAfterTodayAreFuture() {
        let cells = ActivityGrid.make(stats: UsageStats(), today: today).weeks.flatMap { $0 }
        XCTAssertEqual(cells.filter(\.isFuture).count, 3, "Friday, Saturday and Sunday")
        XCTAssertTrue(cells.filter(\.isFuture).allSatisfy { $0.day > today })
        XCTAssertFalse(cells.first { $0.day == today }!.isFuture)
    }

    func testLevelsGrowWithWordsAndEmptyDaysAreZero() {
        let s = stats([today: 100, today.adding(-1): 50, today.adding(-3): 1])
        let cells = ActivityGrid.make(stats: s, today: today).weeks.flatMap { $0 }
        func level(_ d: DayKey) -> Double { cells.first { $0.day == d }!.level }
        XCTAssertEqual(level(today), 1.0, accuracy: 1e-9)
        XCTAssertEqual(level(today.adding(-1)), 0.65, accuracy: 1e-9)
        XCTAssertEqual(level(today.adding(-3)), 0.307, accuracy: 1e-9)
        XCTAssertEqual(level(today.adding(-2)), 0)
        XCTAssertEqual(cells.first { $0.day == today.adding(-1) }!.words, 50)
    }

    func testABusyDayOutsideTheWindowDoesNotDimTheRest() {
        let s = stats([today.adding(-200): 10_000, today: 10])
        let cells = ActivityGrid.make(stats: s, today: today).weeks.flatMap { $0 }
        XCTAssertEqual(cells.first { $0.day == today }!.level, 1.0, accuracy: 1e-9)
        XCTAssertFalse(cells.contains { $0.words == 10_000 })
    }

    func testAGridWithNoActivityIsAllZero() {
        let cells = ActivityGrid.make(stats: UsageStats(), today: today).weeks.flatMap { $0 }
        XCTAssertTrue(cells.allSatisfy { $0.level == 0 && $0.words == 0 })
    }

    func testTheWeekCountCanChangeButNeverDropsBelowOne() {
        XCTAssertEqual(ActivityGrid.make(stats: UsageStats(), today: today, weeks: 4).weeks.count, 4)
        XCTAssertEqual(ActivityGrid.make(stats: UsageStats(), today: today, weeks: 0).weeks.count, 1)
    }
}
