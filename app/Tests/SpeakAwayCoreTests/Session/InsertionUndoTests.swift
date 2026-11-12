import XCTest
@testable import SpeakAwayCore

final class InsertionUndoTests: XCTestCase {
    func testUndoRemovesWhatWasInserted() {
        let last = LastInsertion(inserted: "hello there ")
        let step = InsertionUndo.plan(for: last, contextBeforeCursor: "Hi. hello there ")
        XCTAssertEqual(step, UndoStep(deleteBackward: 12, insert: ""))
    }

    func testCommandUndoPutsTheOriginalTextBack() {
        let last = LastInsertion(inserted: "Hello, how are you?", restoring: "hey how r u")
        let step = InsertionUndo.plan(for: last, contextBeforeCursor: "Hello, how are you?")
        XCTAssertEqual(step, UndoStep(deleteBackward: 19, insert: "hey how r u"))
    }

    func testNothingToUndoWithoutALastInsertion() {
        XCTAssertNil(InsertionUndo.plan(for: nil, contextBeforeCursor: "anything"))
    }

    func testUndoIsRefusedWhenTheUserTypedAfterTheInsertion() {
        let last = LastInsertion(inserted: "hello there ")
        XCTAssertNil(InsertionUndo.plan(for: last, contextBeforeCursor: "hello there and more"))
    }

    func testUndoIsRefusedWhenTheCursorMovedAway() {
        let last = LastInsertion(inserted: "hello there ")
        XCTAssertNil(InsertionUndo.plan(for: last, contextBeforeCursor: "something else"))
        XCTAssertNil(InsertionUndo.plan(for: last, contextBeforeCursor: nil))
    }

    func testAShortenedContextStillMatchesALongInsertion() {
        // The host app only hands the keyboard the last piece of the paragraph.
        let long = String(repeating: "word ", count: 100)
        let last = LastInsertion(inserted: long)
        let truncated = String(long.suffix(80))
        let step = InsertionUndo.plan(for: last, contextBeforeCursor: truncated)
        XCTAssertEqual(step?.deleteBackward, long.count)
    }

    func testAnEmptyContextNeverMatches() {
        XCTAssertNil(InsertionUndo.plan(for: LastInsertion(inserted: "hi "), contextBeforeCursor: ""))
    }

    func testAnEmptyInsertionHasNothingToUndo() {
        XCTAssertNil(InsertionUndo.plan(for: LastInsertion(inserted: ""), contextBeforeCursor: "abc"))
    }

    func testDeletionCountsWhatTheUserSeesNotUTF16Units() {
        let text = "Hola 👨‍👩‍👧 "
        let step = InsertionUndo.plan(for: LastInsertion(inserted: text), contextBeforeCursor: "x " + text)
        XCTAssertEqual(step?.deleteBackward, text.count)
        XCTAssertNotEqual(step?.deleteBackward, text.utf16.count)
    }

    func testInsertionBuiltForACommandRestoresTheTargetWithItsWhitespace() {
        let target = CommandTarget(text: "hey how r u", deleteBackward: 12, leading: "", trailing: " ")
        let insertion = LastInsertion.command(replacing: target, with: "Hello, how are you?")
        XCTAssertEqual(insertion.inserted, "Hello, how are you? ")
        XCTAssertEqual(insertion.restoring, "hey how r u ")
    }

    func testInsertionBuiltForADictationRestoresNothing() {
        let insertion = LastInsertion.dictation("good morning ")
        XCTAssertEqual(insertion.inserted, "good morning ")
        XCTAssertEqual(insertion.restoring, "")
    }
}
