import XCTest
@testable import SpeakAwayCore

final class NoteOutlineTests: XCTestCase {
    func testABlankNoteHasNoTitleAndNoPreview() {
        let outline = NoteOutline(text: "  \n \n\t")
        XCTAssertNil(outline.title)
        XCTAssertNil(outline.preview)
    }

    func testAnEmptyStringHasNoTitleAndNoPreview() {
        let outline = NoteOutline(text: "")
        XCTAssertNil(outline.title)
        XCTAssertNil(outline.preview)
    }

    func testASingleLineIsTheTitleOnly() {
        let outline = NoteOutline(text: "Ideas para el lunes")
        XCTAssertEqual(outline.title, "Ideas para el lunes")
        XCTAssertNil(outline.preview)
    }

    func testBlankLinesAndSpacesBeforeTheTitleAreSkipped() {
        let outline = NoteOutline(text: "\n\n   Lista del super   \n")
        XCTAssertEqual(outline.title, "Lista del super")
        XCTAssertNil(outline.preview)
    }

    func testThePreviewJoinsTheRestOfTheLinesWithOneSpace() {
        let outline = NoteOutline(text: "Lista del super\n\n  leche y pan \nhuevos\n")
        XCTAssertEqual(outline.title, "Lista del super")
        XCTAssertEqual(outline.preview, "leche y pan huevos")
    }

    func testWindowsLineEndingsLeaveNoStrayCharacters() {
        let outline = NoteOutline(text: "Titulo\r\nprimera\r\nsegunda")
        XCTAssertEqual(outline.title, "Titulo")
        XCTAssertEqual(outline.preview, "primera segunda")
    }

    func testALongTitleIsCutAtSixtyCharacters() {
        let outline = NoteOutline(text: String(repeating: "a", count: 90))
        XCTAssertEqual(outline.title?.count, NoteOutline.titleLimit)
        XCTAssertEqual(NoteOutline.titleLimit, 60)
    }

    func testALongPreviewIsCutAtOneHundredTwentyCharacters() {
        let outline = NoteOutline(text: "Titulo\n" + String(repeating: "b", count: 200))
        XCTAssertEqual(outline.preview?.count, NoteOutline.previewLimit)
        XCTAssertEqual(NoteOutline.previewLimit, 120)
    }
}
