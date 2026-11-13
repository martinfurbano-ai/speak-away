import XCTest
@testable import SpeakAwayCore

final class StatFormatTests: XCTestCase {
    private let spanish = Locale(identifier: "es")
    private let english = Locale(identifier: "en_US")

    func testNumbersGroupThousandsTheWayTheLanguageDoes() {
        XCTAssertEqual(StatFormat.number(50_000, locale: spanish), "50.000")
        XCTAssertEqual(StatFormat.number(50_000, locale: english), "50,000")
        XCTAssertEqual(StatFormat.number(1_250_000, locale: english), "1,250,000")
    }

    func testSmallNumbersHaveNoSeparator() {
        XCTAssertEqual(StatFormat.number(0, locale: spanish), "0")
        XCTAssertEqual(StatFormat.number(950, locale: english), "950")
        XCTAssertEqual(StatFormat.number(950, locale: spanish), "950")
    }

    func testTimeSavedUnderAnHourIsInMinutes() {
        XCTAssertEqual(StatFormat.timeSaved(minutes: 0), "0 min")
        XCTAssertEqual(StatFormat.timeSaved(minutes: 45), "45 min")
        XCTAssertEqual(StatFormat.timeSaved(minutes: 59), "59 min")
    }

    func testTimeSavedFromAnHourShowsHoursAndMinutes() {
        XCTAssertEqual(StatFormat.timeSaved(minutes: 60), "1 h 0 min")
        XCTAssertEqual(StatFormat.timeSaved(minutes: 80), "1 h 20 min")
        XCTAssertEqual(StatFormat.timeSaved(minutes: 605), "10 h 5 min")
    }

    func testNegativeTimeIsZero() {
        XCTAssertEqual(StatFormat.timeSaved(minutes: -5), "0 min")
    }

    func testMeetingMinutesRoundDown() {
        XCTAssertEqual(StatFormat.minutes(of: 59), 0)
        XCTAssertEqual(StatFormat.minutes(of: 125.9), 2)
        XCTAssertEqual(StatFormat.minutes(of: -3), 0)
    }
}
