import XCTest
@testable import SpeakAwayCore

/// Pasting borrows the clipboard and gives it back. What comes back must always be the user's own
/// clipboard, never an earlier dictation: otherwise a late Cmd+V pastes the previous transcription again.
final class ClipboardKeeperTests: XCTestCase {
    func testAFreshUserClipboardIsWhatComesBack() {
        let keep = ClipboardKeeper.userClipboard(current: "copied by the user", currentIsOurs: false, remembered: "older")
        XCTAssertEqual(keep, "copied by the user")
    }

    func testAnEarlierDictationLeftOnTheClipboardNeverComesBack() {
        let keep = ClipboardKeeper.userClipboard(current: "last dictation", currentIsOurs: true, remembered: "copied by the user")
        XCTAssertEqual(keep, "copied by the user")
    }

    func testWithNoUserClipboardKnownNothingIsRestored() {
        let keep: String? = ClipboardKeeper.userClipboard(current: "last dictation", currentIsOurs: true, remembered: nil)
        XCTAssertNil(keep)
    }

    func testOurItemsAreMarkedSoTheyCanBeRecognized() {
        XCTAssertTrue(ClipboardKeeper.isOurs(types: ["public.utf8-plain-text", ClipboardKeeper.markerType]))
        XCTAssertFalse(ClipboardKeeper.isOurs(types: ["public.utf8-plain-text"]))
        XCTAssertFalse(ClipboardKeeper.isOurs(types: []))
    }

    func testClipboardManagersAreToldToSkipTheDictation() {
        XCTAssertTrue(ClipboardKeeper.markerTypes.contains("org.nspasteboard.TransientType"))
        XCTAssertTrue(ClipboardKeeper.markerTypes.contains(ClipboardKeeper.markerType))
    }

    func testTheClipboardIsGivenBackOnlyIfNobodyCopiedMeanwhile() {
        XCTAssertTrue(ClipboardKeeper.mayRestore(changeCountNow: 7, ours: 7))
        XCTAssertFalse(ClipboardKeeper.mayRestore(changeCountNow: 8, ours: 7))
    }

    func testTheRestoreWaitsLongEnoughForSlowApps() {
        XCTAssertGreaterThanOrEqual(ClipboardKeeper.restoreDelay, 1.5)
    }
}
