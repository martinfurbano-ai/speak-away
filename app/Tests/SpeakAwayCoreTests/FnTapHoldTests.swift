import XCTest
@testable import SpeakAwayCore

/// Push to talk: hold Fn to record until release; double tap for hands-free, one tap to stop.
final class FnTapHoldTests: XCTestCase {
    private func hold() -> FnTap { FnTap(pushToTalk: true) }

    func testDefaultTapDoesNotUsePushToTalk() {
        let (tap, action) = FnTap().press(at: 1.0, recording: false)
        XCTAssertNil(action)
        let (_, released) = tap.release(at: 3.0, recording: false)
        XCTAssertNil(released)
    }

    func testPressWhileIdleStartsAHoldRecordingRightAway() {
        let (_, action) = hold().press(at: 1.0, recording: false)
        XCTAssertEqual(action, .startHold)
    }

    func testReleasingAfterALongHoldStopsTheRecording() {
        let (a, _) = hold().press(at: 1.0, recording: false)
        let (_, action) = a.release(at: 2.5, recording: true)
        XCTAssertEqual(action, .stop)
    }

    func testReleasingExactlyAtTheThresholdStops() {
        let (a, _) = hold().press(at: 0, recording: false)
        let (_, action) = a.release(at: FnTap.holdThreshold, recording: true)
        XCTAssertEqual(action, .stop)
    }

    func testReleasingBeforeTheThresholdDiscardsTheTentativeRecording() {
        let (a, _) = hold().press(at: 1.0, recording: false)
        let (_, action) = a.release(at: 1.2, recording: true)
        XCTAssertEqual(action, .discard)
    }

    func testReleaseWithoutARecordingDoesNothing() {
        let (a, _) = hold().press(at: 1.0, recording: false)
        let (_, long) = a.release(at: 2.0, recording: false)
        XCTAssertNil(long)
        let (_, short) = a.release(at: 1.1, recording: false)
        XCTAssertNil(short)
    }

    func testDoubleTapStartsHandsFree() {
        let (a, _) = hold().press(at: 1.0, recording: false)
        let (b, discard) = a.release(at: 1.1, recording: true)
        XCTAssertEqual(discard, .discard)
        let (c, start) = b.press(at: 1.3, recording: false)
        XCTAssertEqual(start, .start)
        // Letting go of the second tap must not stop the hands-free recording.
        let (_, released) = c.release(at: 1.4, recording: true)
        XCTAssertNil(released)
    }

    func testHandsFreeIsStoppedByOneTapAndItsReleaseDoesNothing() {
        var (tap, _) = hold().press(at: 1.0, recording: false)
        (tap, _) = tap.release(at: 1.1, recording: true)
        (tap, _) = tap.press(at: 1.3, recording: false)
        (tap, _) = tap.release(at: 1.4, recording: true)
        let (afterPress, stop) = tap.press(at: 8.0, recording: true)
        XCTAssertEqual(stop, .stop)
        let (_, released) = afterPress.release(at: 8.1, recording: false)
        XCTAssertNil(released)
    }

    func testSecondTapAfterTheWindowIsANewHold() {
        let (a, _) = hold().press(at: 1.0, recording: false)
        let (b, _) = a.release(at: 1.1, recording: true)
        let (_, action) = b.press(at: 1.1 + FnTap.window + 0.1, recording: false)
        XCTAssertEqual(action, .startHold)
    }

    func testSecondTapJustInsideTheWindowIsDoubleTap() {
        let (a, _) = hold().press(at: 1.0, recording: false)
        let (b, _) = a.release(at: 1.1, recording: true)
        let (_, action) = b.press(at: 1.1 + FnTap.window - 0.01, recording: false)
        XCTAssertEqual(action, .start)
    }

    func testThirdQuickPressAfterDoubleTapIsNotAnotherDoubleTap() {
        var (tap, _) = hold().press(at: 1.0, recording: false)
        (tap, _) = tap.release(at: 1.1, recording: true)
        (tap, _) = tap.press(at: 1.3, recording: false)
        (tap, _) = tap.release(at: 1.4, recording: true)
        // The recording failed to open, so we are idle again; a fast third press is a plain hold.
        let (_, action) = tap.press(at: 1.5, recording: false)
        XCTAssertEqual(action, .startHold)
    }

    func testPressWhileRecordingStopsEvenIfStartedByHold() {
        let (a, _) = hold().press(at: 1.0, recording: false)
        // A release event was missed; another press while recording stops it.
        let (_, action) = a.press(at: 4.0, recording: true)
        XCTAssertEqual(action, .stop)
    }

    func testLongHoldThenQuickTapDoesNotMakeADoubleTap() {
        let (a, _) = hold().press(at: 1.0, recording: false)
        let (b, stop) = a.release(at: 3.0, recording: true)
        XCTAssertEqual(stop, .stop)
        let (_, action) = b.press(at: 3.1, recording: false)
        XCTAssertEqual(action, .startHold)
    }

    func testAnotherKeyRightAfterPressDiscardsTheTentativeRecording() {
        let (a, _) = hold().press(at: 1.0, recording: false)
        let (b, action) = a.otherKey(at: 1.1, recording: true)
        XCTAssertEqual(action, .discard)
        // Fn+arrow is a modifier use: its release does nothing and no double tap is armed.
        let (c, released) = b.release(at: 1.2, recording: false)
        XCTAssertNil(released)
        let (_, next) = c.press(at: 1.25, recording: false)
        XCTAssertEqual(next, .startHold)
    }

    func testAnotherKeyAfterTheThresholdKeepsRecording() {
        let (a, _) = hold().press(at: 1.0, recording: false)
        let (b, action) = a.otherKey(at: 2.0, recording: true)
        XCTAssertNil(action)
        let (_, stop) = b.release(at: 2.5, recording: true)
        XCTAssertEqual(stop, .stop)
    }

    func testAnotherKeyWhileHandsFreeDoesNotStop() {
        let (b, action) = hold().otherKey(at: 6.0, recording: true)
        XCTAssertNil(action)
        XCTAssertEqual(b, hold())
    }

    func testLegacyOtherKeyStillResetsTheDoubleTap() {
        let (a, _) = FnTap(pushToTalk: true).press(at: 1.0, recording: false)
        let (b, _) = a.release(at: 1.1, recording: true)
        let (_, action) = b.otherKey().press(at: 1.2, recording: false)
        XCTAssertEqual(action, .startHold)
    }

    func testReleaseReturnsANewValueAndKeepsTheOriginal() {
        let (a, _) = hold().press(at: 1.0, recording: false)
        let copy = a
        _ = a.release(at: 2.0, recording: true)
        XCTAssertEqual(a, copy)
    }

    func testDefaultInitKeepsEqualityWithFreshValue() {
        XCTAssertEqual(FnTap(), FnTap(pushToTalk: false))
        XCTAssertNotEqual(FnTap(), FnTap(pushToTalk: true))
    }
}
