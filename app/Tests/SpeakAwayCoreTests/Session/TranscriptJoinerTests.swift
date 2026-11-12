import XCTest
@testable import SpeakAwayCore

final class TranscriptJoinerTests: XCTestCase {
    func testPiecesAreJoinedWithOneSpace() {
        XCTAssertEqual(TranscriptJoiner.join(["Hello there.", "How are you?"]), "Hello there. How are you?")
    }

    func testSpacesAtTheJoinsAreNormalized() {
        XCTAssertEqual(TranscriptJoiner.join([" Hello ", " world "]), "Hello world")
        XCTAssertEqual(TranscriptJoiner.join(["Hello\n", "\nworld"]), "Hello world")
    }

    func testClosingPunctuationAttachesToThePieceBefore() {
        XCTAssertEqual(TranscriptJoiner.join(["Hello", ", world"]), "Hello, world")
        XCTAssertEqual(TranscriptJoiner.join(["Is it ready", "?"]), "Is it ready?")
        XCTAssertEqual(TranscriptJoiner.join(["(a note", ")"]), "(a note)")
    }

    func testSpanishOpeningMarksKeepTheirSpace() {
        XCTAssertEqual(TranscriptJoiner.join(["Hola.", "¿Cómo estás?"]), "Hola. ¿Cómo estás?")
    }

    func testEmptyPiecesAreDropped() {
        XCTAssertEqual(TranscriptJoiner.join([]), "")
        XCTAssertEqual(TranscriptJoiner.join(["", "  ", "\n"]), "")
        XCTAssertEqual(TranscriptJoiner.join(["", "Hello", " ", "world"]), "Hello world")
    }

    func testASinglePieceIsJustTrimmed() {
        XCTAssertEqual(TranscriptJoiner.join(["  Let's meet tomorrow. "]), "Let's meet tomorrow.")
    }

    func testTextInsideAPieceIsLeftAlone() {
        XCTAssertEqual(TranscriptJoiner.join(["Line one\nline two", "line three"]), "Line one\nline two line three")
    }
}
