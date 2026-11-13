import XCTest
@testable import SpeakAwayCore

final class NoteInsertionTests: XCTestCase {
    func testADictationIntoAnEmptyNoteIsTheDictation() {
        XCTAssertEqual(NoteInsertion.appending("Hola equipo", to: ""), "Hola equipo")
    }

    func testItGoesAfterTheLastWordWithOneSpace() {
        XCTAssertEqual(NoteInsertion.appending("y leche", to: "Comprar pan"), "Comprar pan y leche")
    }

    func testNoExtraSpaceWhenTheNoteAlreadyEndsInOne() {
        XCTAssertEqual(NoteInsertion.appending("y leche", to: "Comprar pan "), "Comprar pan y leche")
        XCTAssertEqual(NoteInsertion.appending("Llamar a Carla", to: "Pendientes\n"), "Pendientes\nLlamar a Carla")
    }

    func testTheDictationIsTrimmed() {
        XCTAssertEqual(NoteInsertion.appending("  y leche \n", to: "Comprar pan"), "Comprar pan y leche")
    }

    func testNothingToAddKeepsTheNoteAsItWas() {
        XCTAssertEqual(NoteInsertion.appending("   ", to: "Comprar pan"), "Comprar pan")
        XCTAssertEqual(NoteInsertion.appending("", to: ""), "")
    }

    func testANoteThatEndsInBlanksKeepsThemAndGetsNoExtraSeparator() {
        XCTAssertEqual(NoteInsertion.appending("Hola", to: "  \n "), "  \n Hola")
    }
}
