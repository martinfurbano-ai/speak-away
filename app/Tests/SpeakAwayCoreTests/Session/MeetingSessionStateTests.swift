import XCTest
@testable import SpeakAwayCore

/// What the keyboard sees while a meeting records: the shared state says so, the keyboard cannot dictate.
final class MeetingSessionStateTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private func at(_ seconds: Double) -> Date { t0.addingTimeInterval(seconds) }

    func testTheMeetingStateRoundTripsThroughJSON() throws {
        for paused in [false, true] {
            let data = try JSONEncoder().encode(SessionState.meeting(paused: paused))
            XCTAssertEqual(try JSONDecoder().decode(SessionState.self, from: data), .meeting(paused: paused))
        }
    }

    func testTheMeetingStateIsStoredAsReadableJSON() throws {
        let data = try JSONEncoder().encode(SessionState.meeting(paused: true))
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(text.contains("\"type\":\"meeting\""), text)
        XCTAssertTrue(text.contains("\"paused\":true"), text)
    }

    func testAFileWithoutPausedReadsAsRecording() throws {
        let data = Data(#"{"type":"meeting"}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(SessionState.self, from: data), .meeting(paused: false))
    }

    func testAMeetingIsNeverAMomentToDictate() {
        XCTAssertFalse(SessionState.meeting(paused: false).canRecord)
        XCTAssertFalse(SessionState.meeting(paused: true).canRecord)
        XCTAssertEqual(SessionState.meeting(paused: false).level, 0)
    }

    func testTheKeyboardsRequestsAreIgnoredWhileAMeetingRecords() {
        let messages: [SessionMessage] = [.start, .stop, .cancel, .startCommand(on: "hola"), .command(instruction: "corta", on: "hola")]
        for paused in [false, true] {
            for message in messages {
                XCTAssertEqual(SessionDispatch.intent(for: message, in: .meeting(paused: paused)), .ignore, "\(message) paused \(paused)")
            }
        }
    }

    func testAMeetingKeepsTheKeyboardInformedWithHeartbeats() {
        for paused in [false, true] {
            let state = SessionState.meeting(paused: paused)
            XCTAssertEqual(SessionTick.decide(state: state, publishedAt: t0, sessionEnd: nil, now: at(3)), .none)
            XCTAssertEqual(SessionTick.decide(state: state, publishedAt: t0, sessionEnd: nil, now: at(4)), .heartbeat)
        }
    }

    func testAMeetingNeverEndsWithTheDictationSessionsClock() {
        let action = SessionTick.decide(state: .meeting(paused: false), publishedAt: t0, sessionEnd: at(-100), now: at(10))
        XCTAssertEqual(action, .heartbeat)
    }

    func testTheMicKeyDoesNothingDuringAMeeting() {
        let (gesture, action) = MicGesture().pressed(at: t0, state: .meeting(paused: false))
        XCTAssertEqual(action, .none)
        XCTAssertFalse(gesture.recording)
    }

    func testFollowingAMeetingClearsTheDictationFlag() {
        let gesture = MicGesture(recording: true).following(.meeting(paused: false), at: t0)
        XCTAssertFalse(gesture.recording)
    }

    func testTheBadgeSaysAMeetingRecordsEvenWithoutADictationSession() {
        XCTAssertEqual(SessionBadge.make(state: .meeting(paused: false), sessionEnd: nil, active: false, now: t0),
                       .meeting(paused: false))
        XCTAssertEqual(SessionBadge.make(state: .meeting(paused: true), sessionEnd: nil, active: true, now: t0),
                       .meeting(paused: true))
    }

    func testAMeetingStateNobodyRefreshesReadsAsIdle() {
        let stale = SessionRecord(state: .meeting(paused: false), updatedAt: t0)
        XCTAssertEqual(SessionLiveness.effectiveState(stale, at: at(5)), .meeting(paused: false))
        XCTAssertEqual(SessionLiveness.effectiveState(stale, at: at(13)), .idle)
    }

    func testThePreviewScreenForTheRecordingExists() {
        XCTAssertEqual(PreviewScreen(rawValue: "meeting-recording"), .meetingRecording)
        XCTAssertEqual(PreviewRequest(arguments: ["--preview", "meeting-recording"])?.screen, .meetingRecording)
    }
}
