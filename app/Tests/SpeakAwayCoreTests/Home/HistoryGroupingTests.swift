import XCTest
@testable import SpeakAwayCore

final class HistoryGroupingTests: XCTestCase {
    private let panama: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Panama")!
        return c
    }()

    private func date(_ d: Int, _ h: Int, _ m: Int = 0, month: Int = 11) -> Date {
        panama.date(from: DateComponents(year: 2026, month: month, day: d, hour: h, minute: m))!
    }

    private func item(_ text: String, _ at: Date) -> HistoryItem {
        HistoryItem(date: at, text: text, raw: text, app: nil)
    }

    private var now: Date { date(12, 15) }

    func testNothingGivesNoGroups() {
        XCTAssertTrue(HistoryGrouping.byDay([], now: now, calendar: panama).isEmpty)
    }

    func testTodayYesterdayAndOlderDaysGetTheirOwnGroup() {
        let items = [
            item("hoy tarde", date(12, 9)), item("ayer noche", date(11, 23, 59)),
            item("hoy temprano", date(12, 0, 1)), item("viejo", date(1, 10)),
        ]
        let groups = HistoryGrouping.byDay(items, now: now, calendar: panama)
        XCTAssertEqual(groups.count, 3)
        XCTAssertEqual(groups[0].label, .today)
        XCTAssertEqual(groups[1].label, .yesterday)
        guard case .date(let older) = groups[2].label else { return XCTFail("expected a date label") }
        XCTAssertEqual(DayKey(older, calendar: panama), DayKey(date(1, 10), calendar: panama))
    }

    func testGroupsAndItemsAreNewestFirst() {
        let items = [item("a", date(11, 8)), item("b", date(12, 8)), item("c", date(12, 14)), item("d", date(11, 20))]
        let groups = HistoryGrouping.byDay(items, now: now, calendar: panama)
        XCTAssertEqual(groups.map { $0.items.map(\.text) }, [["c", "b"], ["d", "a"]])
    }

    func testItemsWithTheSameTimeKeepTheirOrder() {
        let items = [item("x", date(12, 9)), item("y", date(12, 9)), item("z", date(12, 9))]
        XCTAssertEqual(HistoryGrouping.byDay(items, now: now, calendar: panama)[0].items.map(\.text), ["x", "y", "z"])
    }

    func testMidnightSeparatesTheDays() {
        let items = [item("late", date(11, 23, 59)), item("early", date(12, 0, 0))]
        let groups = HistoryGrouping.byDay(items, now: now, calendar: panama)
        XCTAssertEqual(groups.map(\.label), [.today, .yesterday])
    }

    func testADateFromTheFutureIsNotCalledToday() {
        let groups = HistoryGrouping.byDay([item("later", date(13, 9))], now: now, calendar: panama)
        guard case .date = groups[0].label else { return XCTFail("expected a date label") }
    }

    func testGroupsHaveStableIdentifiers() {
        let groups = HistoryGrouping.byDay([item("a", date(12, 8)), item("b", date(11, 8))], now: now, calendar: panama)
        XCTAssertEqual(Set(groups.map(\.id)).count, 2)
    }
}
