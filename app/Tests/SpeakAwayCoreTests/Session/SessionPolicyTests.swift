import XCTest
@testable import SpeakAwayCore

final class SessionPolicyTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: lengths

    func testLengthsMatchWhatTheUserCanPick() {
        XCTAssertEqual(SessionLength.allCases, [.fiveMinutes, .fifteenMinutes, .oneHour, .untilStopped])
        XCTAssertEqual(SessionLength.fiveMinutes.duration, 300)
        XCTAssertEqual(SessionLength.fifteenMinutes.duration, 900)
        XCTAssertEqual(SessionLength.oneHour.duration, 3600)
        XCTAssertNil(SessionLength.untilStopped.duration)
    }

    func testEveryLengthHasATitle() {
        for length in SessionLength.allCases {
            XCTAssertFalse(length.title.isEmpty)
        }
        XCTAssertEqual(SessionLength.fiveMinutes.title, "5 minutes")
        XCTAssertEqual(SessionLength.oneHour.title, "1 hour")
    }

    func testLengthIsStoredAsReadableText() throws {
        let data = try JSONEncoder().encode(SessionPolicy(length: .oneHour))
        XCTAssertEqual(String(decoding: data, as: UTF8.self), #"{"length":"oneHour"}"#)
        XCTAssertEqual(try JSONDecoder().decode(SessionPolicy.self, from: data), SessionPolicy(length: .oneHour))
    }

    // MARK: expiry

    func testDefaultPolicyIsFifteenMinutes() {
        XCTAssertEqual(SessionPolicy().length, .fifteenMinutes)
    }

    func testExpiryIsStartPlusLength() {
        XCTAssertEqual(SessionPolicy(length: .fiveMinutes).expiry(from: t0), t0.addingTimeInterval(300))
        XCTAssertEqual(SessionPolicy(length: .oneHour).expiry(from: t0), t0.addingTimeInterval(3600))
    }

    func testUntilStoppedNeverExpires() {
        XCTAssertNil(SessionPolicy(length: .untilStopped).expiry(from: t0))
    }

    func testStartingASessionGivesAReadyState() {
        XCTAssertEqual(SessionPolicy(length: .fiveMinutes).startedState(at: t0), .ready(until: t0.addingTimeInterval(300)))
        XCTAssertEqual(SessionPolicy(length: .untilStopped).startedState(at: t0), .ready(until: nil))
    }

    // MARK: remaining time

    func testRemainingCountsDownAndStopsAtZero() {
        let until = t0.addingTimeInterval(300)
        XCTAssertEqual(SessionPolicy.remaining(until: until, at: t0), 300)
        XCTAssertEqual(SessionPolicy.remaining(until: until, at: t0.addingTimeInterval(120)), 180)
        XCTAssertEqual(SessionPolicy.remaining(until: until, at: t0.addingTimeInterval(900)), 0)
        XCTAssertNil(SessionPolicy.remaining(until: nil, at: t0))
    }

    func testIsExpired() {
        let until = t0.addingTimeInterval(300)
        XCTAssertFalse(SessionPolicy.isExpired(until: until, at: t0.addingTimeInterval(299)))
        XCTAssertTrue(SessionPolicy.isExpired(until: until, at: t0.addingTimeInterval(300)))
        XCTAssertTrue(SessionPolicy.isExpired(until: until, at: t0.addingTimeInterval(301)))
        XCTAssertFalse(SessionPolicy.isExpired(until: nil, at: t0.addingTimeInterval(1_000_000)))
    }

    // MARK: reading a state that may be stale

    func testAnExpiredReadyStateReadsAsIdle() {
        let state = SessionState.ready(until: t0.addingTimeInterval(300))
        XCTAssertEqual(SessionPolicy.reconciled(state, at: t0.addingTimeInterval(301)), .idle)
    }

    func testALiveReadyStateIsKept() {
        let state = SessionState.ready(until: t0.addingTimeInterval(300))
        XCTAssertEqual(SessionPolicy.reconciled(state, at: t0.addingTimeInterval(10)), state)
        XCTAssertEqual(SessionPolicy.reconciled(.ready(until: nil), at: t0), .ready(until: nil))
    }

    func testOtherStatesAreNeverChangedByTheClock() {
        let late = t0.addingTimeInterval(86_400)
        let id = UUID()
        for state in [SessionState.idle, .recording(level: 0.3), .transcribing, .done(id: id, text: "x"), .failed(reason: "y")] {
            XCTAssertEqual(SessionPolicy.reconciled(state, at: late), state)
        }
    }
}
