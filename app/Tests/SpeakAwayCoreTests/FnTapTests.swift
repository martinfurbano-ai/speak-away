import XCTest
@testable import SpeakAwayCore

final class FnTapTests: XCTestCase {
    func testOneTapWhileIdleDoesNothing() {
        let (_, action) = FnTap().press(at: 1.0, recording: false)
        XCTAssertNil(action)
    }

    func testTwoQuickTapsStartRecording() {
        let (tap, _) = FnTap().press(at: 1.0, recording: false)
        let (_, action) = tap.press(at: 1.3, recording: false)
        XCTAssertEqual(action, .start)
    }

    func testTwoSlowTapsDoNotStart() {
        let (tap, _) = FnTap().press(at: 1.0, recording: false)
        let (_, action) = tap.press(at: 1.5, recording: false)
        XCTAssertNil(action)
    }

    func testOneTapWhileRecordingStops() {
        let (_, action) = FnTap().press(at: 5.0, recording: true)
        XCTAssertEqual(action, .stop)
    }

    func testThirdQuickTapIsNotReadAsAnotherDoubleTap() {
        let (a, _) = FnTap().press(at: 1.0, recording: false)
        let (b, start) = a.press(at: 1.2, recording: false)
        XCTAssertEqual(start, .start)
        // The recording failed to open, so we are idle again; a fast third tap must not restart it.
        let (_, action) = b.press(at: 1.35, recording: false)
        XCTAssertNil(action)
    }

    func testAnotherKeyBetweenTapsCancelsTheDoubleTap() {
        let (a, _) = FnTap().press(at: 1.0, recording: false)
        let (_, action) = a.otherKey().press(at: 1.2, recording: false)
        XCTAssertNil(action)
    }

    func testPressReturnsANewValueAndKeepsTheOriginal() {
        let original = FnTap()
        _ = original.press(at: 1.0, recording: false)
        XCTAssertEqual(original, FnTap())
    }
}
