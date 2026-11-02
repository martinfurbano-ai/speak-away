import XCTest
@testable import SpeakAwayCore

/// The Fn (Globe) key belongs to Speak Away: macOS must never open the emoji panel, switch the input
/// source or start its own dictation with it, or the transcription gets pasted into that panel.
final class FnKeyGuardTests: XCTestCase {
    // MARK: Which events never reach other apps

    func testTheFnKeyGoingDownOrUpIsSwallowed() {
        XCTAssertTrue(FnKeyGuard.swallows(.flagsChanged, keyCode: 63))
    }

    func testTheGlobeKeyPressIsSwallowed() {
        XCTAssertTrue(FnKeyGuard.swallows(.keyDown, keyCode: 179))
        XCTAssertTrue(FnKeyGuard.swallows(.keyUp, keyCode: 179))
    }

    func testOtherModifiersStillReachApps() {
        XCTAssertFalse(FnKeyGuard.swallows(.flagsChanged, keyCode: 59)) // Control
        XCTAssertFalse(FnKeyGuard.swallows(.flagsChanged, keyCode: 55)) // Command
    }

    func testNormalKeysStillReachApps() {
        XCTAssertFalse(FnKeyGuard.swallows(.keyDown, keyCode: 0))   // A
        XCTAssertFalse(FnKeyGuard.swallows(.keyDown, keyCode: 126)) // Up arrow, also Fn + Up
        XCTAssertFalse(FnKeyGuard.swallows(.keyDown, keyCode: 63))
    }

    // MARK: The "Press Globe key to" system setting

    func testTurnsOffTheGlobeKeyWhenItShowsEmoji() {
        let plan = FnKeyGuard.takeOver(current: 2)
        XCTAssertEqual(plan, FnKeyGuard.TakeOver(write: 0, remember: .value(2)))
    }

    func testTurnsOffTheGlobeKeyWhenTheSettingWasNeverTouched() {
        // No value means the macOS default, which on Globe keyboards is the emoji panel.
        let plan = FnKeyGuard.takeOver(current: nil)
        XCTAssertEqual(plan, FnKeyGuard.TakeOver(write: 0, remember: .absent))
    }

    func testLeavesTheSettingAloneWhenItAlreadyDoesNothing() {
        XCTAssertNil(FnKeyGuard.takeOver(current: 0))
    }

    func testOnQuitPutsBackTheValueThePersonHad() {
        XCTAssertEqual(FnKeyGuard.restore(.value(1)), .write(1))
        XCTAssertEqual(FnKeyGuard.restore(.absent), .remove)
    }

    func testRememberedValueRoundTripsThroughStorage() {
        for saved in [FnKeyGuard.Saved.absent, .value(0), .value(2), .value(3)] {
            XCTAssertEqual(FnKeyGuard.Saved(stored: saved.stored), saved)
        }
        XCTAssertNil(FnKeyGuard.Saved(stored: nil))
    }
}
