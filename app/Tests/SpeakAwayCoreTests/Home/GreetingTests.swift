import XCTest
@testable import SpeakAwayCore

final class GreetingTests: XCTestCase {
    private let panama: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Panama")!
        return c
    }()

    private func date(hour: Int, minute: Int = 0) -> Date {
        panama.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: hour, minute: minute))!
    }

    func testMorningUntilNoon() {
        for hour in [0, 5, 11] { XCTAssertEqual(Greeting.forHour(hour), .morning, "hour \(hour)") }
    }

    func testAfternoonFromNoonUntilSeven() {
        for hour in [12, 15, 18] { XCTAssertEqual(Greeting.forHour(hour), .afternoon, "hour \(hour)") }
    }

    func testEveningFromSevenOn() {
        for hour in [19, 21, 23] { XCTAssertEqual(Greeting.forHour(hour), .evening, "hour \(hour)") }
    }

    func testTheGreetingFollowsTheHourOfTheCalendar() {
        XCTAssertEqual(Greeting.at(date(hour: 11, minute: 59), calendar: panama), .morning)
        XCTAssertEqual(Greeting.at(date(hour: 12), calendar: panama), .afternoon)
        XCTAssertEqual(Greeting.at(date(hour: 18, minute: 59), calendar: panama), .afternoon)
        XCTAssertEqual(Greeting.at(date(hour: 19), calendar: panama), .evening)
    }
}
