import XCTest
@testable import SpeakAwayCore

final class SessionRecordTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func record(_ state: SessionState, age: TimeInterval = 0, command: Bool = false) -> SessionRecord {
        SessionRecord(state: state, updatedAt: now.addingTimeInterval(-age), command: command)
    }

    // MARK: Coding

    func testRecordSurvivesARoundTrip() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let original = record(.done(id: UUID(), text: "hello "), command: true)
        XCTAssertEqual(try decoder.decode(SessionRecord.self, from: encoder.encode(original)), original)
    }

    func testRecordWithoutACommandFlagDecodesAsADictation() throws {
        let json = #"{"state":{"type":"transcribing"},"updatedAt":"2027-01-15T08:00:00Z"}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SessionRecord.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.state, .transcribing)
        XCTAssertFalse(decoded.command)
    }

    // MARK: What the keyboard should believe

    func testNoRecordMeansNoSession() {
        XCTAssertEqual(SessionLiveness.effectiveState(nil, at: now), .idle)
        XCTAssertFalse(SessionLiveness.isLive(nil, at: now))
    }

    func testAFreshReadyStateIsLive() {
        let until = now.addingTimeInterval(600)
        let r = record(.ready(until: until), age: 2)
        XCTAssertEqual(SessionLiveness.effectiveState(r, at: now), .ready(until: until))
        XCTAssertTrue(SessionLiveness.isLive(r, at: now))
    }

    func testAReadyStateThatNobodyRefreshedMeansTheAppIsGone() {
        let r = record(.ready(until: now.addingTimeInterval(600)), age: SessionLiveness.staleAfter + 1)
        XCTAssertEqual(SessionLiveness.effectiveState(r, at: now), .idle)
        XCTAssertFalse(SessionLiveness.isLive(r, at: now))
    }

    func testTheStaleLimitIsLongerThanTheHeartbeat() {
        XCTAssertGreaterThan(SessionLiveness.staleAfter, SessionLiveness.heartbeatInterval * 2)
    }

    func testAReadyStatePastItsEndIsIdleEvenWhenRefreshed() {
        let r = record(.ready(until: now.addingTimeInterval(-1)), age: 1)
        XCTAssertEqual(SessionLiveness.effectiveState(r, at: now), .idle)
    }

    func testAReadyStateWithoutAnEndStaysLive() {
        let r = record(.ready(until: nil), age: 3)
        XCTAssertTrue(SessionLiveness.isLive(r, at: now))
    }

    func testStaleRecordingTranscribingAndDoneAreIdleToo() {
        let old = SessionLiveness.staleAfter + 1
        XCTAssertEqual(SessionLiveness.effectiveState(record(.recording(level: 0.5), age: old), at: now), .idle)
        XCTAssertEqual(SessionLiveness.effectiveState(record(.transcribing, age: old), at: now), .idle)
        XCTAssertEqual(SessionLiveness.effectiveState(record(.done(id: UUID(), text: "x"), age: old), at: now), .idle)
    }

    func testEveryFreshStateExceptIdleIsLive() {
        let states: [SessionState] = [
            .ready(until: nil), .recording(level: 0.2), .transcribing, .done(id: UUID(), text: "hi"), .failed(reason: "No mic"),
        ]
        for state in states {
            XCTAssertTrue(SessionLiveness.isLive(record(state, age: 1), at: now), "\(state)")
        }
        XCTAssertFalse(SessionLiveness.isLive(record(.idle, age: 1), at: now))
    }

    // MARK: Inserting each result once

    func testAFreshUnhandledResultIsPending() {
        let id = UUID()
        let pending = ResultInbox().pending(in: record(.done(id: id, text: "hello "), age: 1), at: now)
        XCTAssertEqual(pending?.id, id)
        XCTAssertEqual(pending?.text, "hello ")
        XCTAssertEqual(pending?.command, false)
    }

    func testACommandResultSaysSo() {
        let pending = ResultInbox().pending(in: record(.done(id: UUID(), text: "Hey."), command: true), at: now)
        XCTAssertEqual(pending?.command, true)
    }

    func testAResultThatWasInsertedIsNotPendingAgain() {
        let id = UUID()
        let inbox = ResultInbox().marking(id)
        XCTAssertNil(inbox.pending(in: record(.done(id: id, text: "hello ")), at: now))
    }

    func testAnotherResultIsPendingAfterOneWasInserted() {
        let inbox = ResultInbox().marking(UUID())
        XCTAssertNotNil(inbox.pending(in: record(.done(id: UUID(), text: "next ")), at: now))
    }

    func testAnOldResultIsNotInserted() {
        let r = record(.done(id: UUID(), text: "late "), age: ResultInbox.maxAge + 1)
        XCTAssertNil(ResultInbox().pending(in: r, at: now))
    }

    func testOtherStatesAreNeverResults() {
        XCTAssertNil(ResultInbox().pending(in: record(.transcribing), at: now))
        XCTAssertNil(ResultInbox().pending(in: record(.ready(until: nil)), at: now))
        XCTAssertNil(ResultInbox().pending(in: nil, at: now))
    }

    func testAResultWithNoTextIsNotPending() {
        XCTAssertNil(ResultInbox().pending(in: record(.done(id: UUID(), text: "")), at: now))
    }

    func testMarkingReturnsANewInboxAndKeepsTheOldOne() {
        let first = ResultInbox()
        let id = UUID()
        let second = first.marking(id)
        XCTAssertNil(first.handled)
        XCTAssertEqual(second.handled, id)
    }
}
