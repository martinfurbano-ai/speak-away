import XCTest
@testable import SpeakAwayCore

final class SessionBadgeTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func badge(_ state: SessionState, end: TimeInterval? = nil, active: Bool = true) -> SessionBadge {
        SessionBadge.make(state: state, sessionEnd: end.map { now.addingTimeInterval($0) }, active: active, now: now)
    }

    func testNoSessionIsOffWhateverTheLastPublishedStateWas() {
        XCTAssertEqual(badge(.idle, active: false), .off)
        XCTAssertEqual(badge(.ready(until: now.addingTimeInterval(600)), end: 600, active: false), .off)
        XCTAssertEqual(badge(.recording(level: 0.4), active: false), .off)
    }

    func testReadyCountsTheMinutesLeftToTheNearestMinute() {
        XCTAssertEqual(badge(.ready(until: nil), end: 12 * 60), .ready(minutesLeft: 12))
        XCTAssertEqual(badge(.ready(until: nil), end: 12 * 60 + 20), .ready(minutesLeft: 12))
        XCTAssertEqual(badge(.ready(until: nil), end: 12 * 60 + 40), .ready(minutesLeft: 13))
    }

    func testReadyNeverShowsZeroMinutes() {
        XCTAssertEqual(badge(.ready(until: nil), end: 10), .ready(minutesLeft: 1))
        XCTAssertEqual(badge(.ready(until: nil), end: 0), .ready(minutesLeft: 1))
        XCTAssertEqual(badge(.ready(until: nil), end: -30), .ready(minutesLeft: 1))
    }

    func testASessionThatEndsWhenTheUserStopsItShowsNoMinutes() {
        XCTAssertEqual(badge(.ready(until: nil), end: nil), .ready(minutesLeft: nil))
    }

    func testTheEndOfTheSessionComesFromTheControllerNotFromThePublishedState() {
        XCTAssertEqual(badge(.ready(until: now.addingTimeInterval(60)), end: 30 * 60), .ready(minutesLeft: 30))
    }

    func testAnActiveSessionThatHasNotPublishedYetIsReady() {
        XCTAssertEqual(badge(.idle, end: 5 * 60), .ready(minutesLeft: 5))
    }

    func testRecordingAndTranscribingHaveTheirOwnBadges() {
        XCTAssertEqual(badge(.recording(level: 0.7), end: 600), .listening)
        XCTAssertEqual(badge(.transcribing, end: 600), .writing)
    }

    func testAResultKeepsTheSessionReady() {
        XCTAssertEqual(badge(.done(id: UUID(), text: "Hola"), end: 9 * 60), .ready(minutesLeft: 9))
    }

    func testAFailureIsAProblem() {
        XCTAssertEqual(badge(.failed(reason: "No mic"), end: 600), .problem)
    }
}
