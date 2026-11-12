import XCTest
@testable import SpeakAwayCore

final class MicGestureTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private let ready = SessionState.ready(until: nil)

    private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    // MARK: Opening the app

    func testWithoutASessionTheMicOpensTheApp() {
        let (gesture, action) = MicGesture().pressed(at: t0, state: .idle)
        XCTAssertEqual(action, .openApp)
        XCTAssertFalse(gesture.recording)
        XCTAssertEqual(gesture.released(at: at(0.1)).1, .none)
    }

    func testAFailedSessionAlsoOpensTheApp() {
        XCTAssertEqual(MicGesture().pressed(at: t0, state: .failed(reason: "No mic")).1, .openApp)
    }

    // MARK: Tap to start, tap to stop

    func testTapStartsAndTheNextTapStops() {
        let (afterPress, start) = MicGesture().pressed(at: t0, state: ready)
        XCTAssertEqual(start, .start)
        XCTAssertTrue(afterPress.recording)

        let (afterTap, release) = afterPress.released(at: at(0.1))
        XCTAssertEqual(release, .none)
        XCTAssertTrue(afterTap.recording, "a short tap keeps recording")

        let (afterSecondPress, stop) = afterTap.pressed(at: at(5), state: .recording(level: 0.4))
        XCTAssertEqual(stop, .stop)
        XCTAssertFalse(afterSecondPress.recording)
        XCTAssertEqual(afterSecondPress.released(at: at(5.1)).1, .none, "the release of the stopping tap does nothing")
    }

    func testTheSecondTapStopsEvenBeforeTheAppReportsRecording() {
        let (afterPress, _) = MicGesture().pressed(at: t0, state: ready)
        let (afterTap, _) = afterPress.released(at: at(0.1))
        // The app has not published `recording` yet: the state is still `ready`.
        XCTAssertEqual(afterTap.pressed(at: at(0.4), state: ready).1, .stop)
    }

    // MARK: Hold to talk

    func testHoldingThenReleasingStops() {
        let (afterPress, start) = MicGesture().pressed(at: t0, state: ready)
        XCTAssertEqual(start, .start)
        let (afterRelease, stop) = afterPress.released(at: at(MicGesture.holdSeconds + 0.5))
        XCTAssertEqual(stop, .stop)
        XCTAssertFalse(afterRelease.recording)
    }

    func testReleasingJustBeforeTheHoldLimitIsStillATap() {
        let (afterPress, _) = MicGesture().pressed(at: t0, state: ready)
        XCTAssertEqual(afterPress.released(at: at(MicGesture.holdSeconds - 0.05)).1, .none)
    }

    func testReleasingWithoutAPressDoesNothing() {
        XCTAssertEqual(MicGesture().released(at: t0).1, .none)
    }

    // MARK: Other states

    func testPressingWhileTranscribingDoesNothing() {
        XCTAssertEqual(MicGesture().pressed(at: t0, state: .transcribing).1, .none)
    }

    func testPressingWhileTheAppReportsRecordingStops() {
        // For example the keyboard was recreated in the middle of a dictation.
        let (gesture, action) = MicGesture().pressed(at: t0, state: .recording(level: 0.3))
        XCTAssertEqual(action, .stop)
        XCTAssertFalse(gesture.recording)
    }

    func testAFinishedDictationDoesNotBlockTheNextOne() {
        let done = SessionState.done(id: UUID(), text: "hi ")
        let (gesture, action) = MicGesture().pressed(at: t0, state: done)
        XCTAssertEqual(action, .start)
        XCTAssertTrue(gesture.recording)
    }

    // MARK: Following the app

    func testFollowingARecordingStateMakesTheNextPressStop() {
        let gesture = MicGesture().following(.recording(level: 0.2), at: t0)
        XCTAssertTrue(gesture.recording)
        XCTAssertEqual(gesture.pressed(at: at(1), state: .recording(level: 0.2)).1, .stop)
    }

    func testFollowingTranscribingEndsTheLocalRecording() {
        let (afterPress, _) = MicGesture().pressed(at: t0, state: ready)
        XCTAssertFalse(afterPress.following(.transcribing, at: at(3)).recording)
    }

    func testAReadyStateRightAfterStartingDoesNotCancelTheLocalRecording() {
        let (afterPress, _) = MicGesture().pressed(at: t0, state: ready)
        XCTAssertTrue(afterPress.following(ready, at: at(0.3)).recording)
    }

    func testAReadyStateLongAfterStartingMeansTheRecordingEnded() {
        let (afterPress, _) = MicGesture().pressed(at: t0, state: ready)
        XCTAssertFalse(afterPress.following(ready, at: at(MicGesture.startGrace + 0.5)).recording)
    }

    func testIdleEndsTheLocalRecordingAtOnce() {
        let (afterPress, _) = MicGesture().pressed(at: t0, state: ready)
        XCTAssertFalse(afterPress.following(.idle, at: at(0.2)).recording)
    }

    func testFollowingDoesNotMutateTheOldGesture() {
        let (afterPress, _) = MicGesture().pressed(at: t0, state: ready)
        _ = afterPress.following(.idle, at: at(0.2))
        XCTAssertTrue(afterPress.recording)
    }
}
