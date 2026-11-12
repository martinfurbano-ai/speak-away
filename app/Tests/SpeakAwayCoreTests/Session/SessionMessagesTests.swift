import XCTest
@testable import SpeakAwayCore

final class SessionMessagesTests: XCTestCase {
    private func roundTrip<T: Codable & Equatable>(_ value: T, file: StaticString = #filePath, line: UInt = #line) throws -> T {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: encoder.encode(value))
    }

    private func jsonObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let object = try JSONSerialization.jsonObject(with: encoder.encode(value))
        return try XCTUnwrap(object as? [String: Any])
    }

    // MARK: SessionMessage (keyboard to app)

    func testEveryMessageSurvivesARoundTrip() throws {
        let messages: [SessionMessage] = [
            .start, .stop, .cancel,
            .command(instruction: "make it formal", on: "hey, send me the file"),
        ]
        for message in messages {
            XCTAssertEqual(try roundTrip(message), message)
        }
    }

    func testMessagesUseAReadableTypeKey() throws {
        XCTAssertEqual(try jsonObject(SessionMessage.stop)["type"] as? String, "stop")
        let command = try jsonObject(SessionMessage.command(instruction: "shorter", on: "a long text"))
        XCTAssertEqual(command["type"] as? String, "command")
        XCTAssertEqual(command["instruction"] as? String, "shorter")
        XCTAssertEqual(command["text"] as? String, "a long text")
    }

    func testUnknownMessageTypeFailsToDecode() {
        let data = Data(#"{"type":"explode"}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(SessionMessage.self, from: data))
    }

    // MARK: SessionRequest (the file the keyboard writes)

    func testRequestKeepsItsIDAndDate() throws {
        let id = UUID()
        let sent = Date(timeIntervalSince1970: 1_800_000_000)
        let request = SessionRequest(id: id, sentAt: sent, message: .start)
        let decoded = try roundTrip(request)
        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.sentAt, sent)
        XCTAssertEqual(decoded.message, .start)
    }

    func testTwoRequestsGetDifferentIDs() {
        XCTAssertNotEqual(SessionRequest(message: .start).id, SessionRequest(message: .start).id)
    }

    // MARK: SessionState (app to keyboard)

    func testEveryStateSurvivesARoundTrip() throws {
        let until = Date(timeIntervalSince1970: 1_800_000_900)
        let states: [SessionState] = [
            .idle,
            .ready(until: until),
            .ready(until: nil),
            .recording(level: 0.42),
            .transcribing,
            .done(id: UUID(), text: "Hello there."),
            .failed(reason: "Microphone is busy"),
        ]
        for state in states {
            XCTAssertEqual(try roundTrip(state), state)
        }
    }

    func testReadyWithoutADateMeansUntilStopped() throws {
        let object = try jsonObject(SessionState.ready(until: nil))
        XCTAssertEqual(object["type"] as? String, "ready")
        XCTAssertNil(object["until"])
    }

    func testStateTypeKeysAreStable() throws {
        XCTAssertEqual(try jsonObject(SessionState.idle)["type"] as? String, "idle")
        XCTAssertEqual(try jsonObject(SessionState.transcribing)["type"] as? String, "transcribing")
        XCTAssertEqual(try jsonObject(SessionState.recording(level: 0.1))["type"] as? String, "recording")
        XCTAssertEqual(try jsonObject(SessionState.failed(reason: "x"))["type"] as? String, "failed")
        let done = try jsonObject(SessionState.done(id: UUID(), text: "hi"))
        XCTAssertEqual(done["type"] as? String, "done")
        XCTAssertEqual(done["text"] as? String, "hi")
    }

    func testUnknownStateTypeFailsToDecode() {
        let data = Data(#"{"type":"levitating"}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(SessionState.self, from: data))
    }

    func testRecordingLevelIsClampedToZeroToOne() {
        XCTAssertEqual(SessionState.recording(level: 3).level, 1)
        XCTAssertEqual(SessionState.recording(level: -2).level, 0)
        XCTAssertEqual(SessionState.recording(level: 0.5).level, 0.5)
        XCTAssertEqual(SessionState.idle.level, 0)
    }

    func testCanStartRecordingOnlyWhenReady() {
        XCTAssertTrue(SessionState.ready(until: nil).canRecord)
        XCTAssertTrue(SessionState.ready(until: Date()).canRecord)
        XCTAssertFalse(SessionState.idle.canRecord)
        XCTAssertFalse(SessionState.recording(level: 0).canRecord)
        XCTAssertFalse(SessionState.transcribing.canRecord)
        XCTAssertFalse(SessionState.failed(reason: "x").canRecord)
    }

    // MARK: Names shared by both sides

    func testChannelNamesAreStableAndDistinct() {
        XCTAssertEqual(SessionChannel.appGroupID, "group.com.opensourceeverything.speakaway")
        XCTAssertEqual(SessionChannel.urlScheme, "speakaway")
        XCTAssertNotEqual(SessionChannel.requestFile, SessionChannel.stateFile)
        XCTAssertNotEqual(SessionChannel.requestNotification, SessionChannel.stateNotification)
        XCTAssertTrue(SessionChannel.requestFile.hasSuffix(".json"))
        XCTAssertTrue(SessionChannel.stateFile.hasSuffix(".json"))
        XCTAssertTrue(SessionChannel.requestNotification.hasPrefix("com.opensourceeverything.speakaway."))
        XCTAssertTrue(SessionChannel.stateNotification.hasPrefix("com.opensourceeverything.speakaway."))
    }

    func testStartURLUsesTheAppScheme() {
        XCTAssertEqual(SessionChannel.startURL.scheme, "speakaway")
        XCTAssertEqual(SessionChannel.startURL.host, "session")
    }
}
