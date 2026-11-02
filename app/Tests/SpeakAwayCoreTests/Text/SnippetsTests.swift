import XCTest
@testable import SpeakAwayCore

final class SnippetsTests: XCTestCase {
    private let snippets = Snippets(items: [
        Snippet(trigger: "mi link de calendario", expansion: "https://cal.com/martin"),
        Snippet(trigger: "my email", expansion: "martin@example.com"),
        Snippet(trigger: "firma", expansion: "Saludos,\nMartín"),
    ])

    func testWholeUtteranceIgnoresCasePunctuationAndTrailingPeriod() {
        XCTAssertEqual(snippets.expand("Mi link de calendario."), "https://cal.com/martin")
    }

    func testAccentAndCaseInsensitive() {
        XCTAssertEqual(snippets.expand("FIRMÁ"), "Saludos,\nMartín")
        let s = Snippets(items: [Snippet(trigger: "dirección", expansion: "Calle 50")])
        XCTAssertEqual(s.expand("direccion"), "Calle 50")
        XCTAssertEqual(s.expand("DIRECCIÓN."), "Calle 50")
    }

    func testInlineMatchKeepsTheRestOfTheSentence() {
        XCTAssertEqual(
            snippets.expand("Agenda conmigo en mi link de calendario, gracias"),
            "Agenda conmigo en https://cal.com/martin, gracias")
    }

    func testPunctuationBetweenTriggerWordsIsTolerated() {
        XCTAssertEqual(snippets.expand("Mira, mi link, de calendario"), "Mira, https://cal.com/martin")
    }

    func testSeveralSnippetsInOneText() {
        XCTAssertEqual(
            snippets.expand("Write to my email or use mi link de calendario"),
            "Write to martin@example.com or use https://cal.com/martin")
    }

    func testWholeWordsOnly() {
        XCTAssertEqual(snippets.expand("la firmadora"), "la firmadora")
        XCTAssertEqual(snippets.expand("my emails"), "my emails")
    }

    func testNoMatchLeavesTextUntouched() {
        XCTAssertEqual(snippets.expand("Hola, ¿cómo estás?"), "Hola, ¿cómo estás?")
    }

    func testTrailingSpaceFromSpeechGateIsKept() {
        XCTAssertEqual(snippets.expand("My email. "), "martin@example.com ")
    }

    func testInlineExpansionEndingInPunctuationDoesNotDoubleIt() {
        let s = Snippets(items: [Snippet(trigger: "mi despedida", expansion: "Un abrazo.")])
        XCTAssertEqual(s.expand("Gracias por todo, mi despedida."), "Gracias por todo, Un abrazo.")
    }

    func testLongerTriggerWinsOverShorter() {
        let s = Snippets(items: [
            Snippet(trigger: "mi correo", expansion: "A"),
            Snippet(trigger: "mi correo de trabajo", expansion: "B"),
        ])
        XCTAssertEqual(s.expand("usa mi correo de trabajo ahora"), "usa B ahora")
    }

    func testEmptyTriggerIsIgnored() {
        let s = Snippets(items: [Snippet(trigger: "  ", expansion: "X")])
        XCTAssertEqual(s.expand("hola"), "hola")
    }

    func testReportsWhenTheWholeUtteranceWasASnippet() {
        XCTAssertTrue(snippets.expandWithInfo("Mi link de calendario.").replacedWholeUtterance)
        XCTAssertFalse(snippets.expandWithInfo("Usa mi link de calendario").replacedWholeUtterance)
        XCTAssertFalse(snippets.expandWithInfo("Hola").replacedWholeUtterance)
    }

    func testAddingAndRemovingReturnNewValues() {
        let added = snippets.adding(Snippet(trigger: "MY EMAIL", expansion: "otro@example.com"))
        XCTAssertEqual(added.items.count, 3)
        XCTAssertEqual(added.expand("my email"), "otro@example.com")
        XCTAssertEqual(snippets.items.count, 3)
        XCTAssertEqual(snippets.expand("my email"), "martin@example.com")
        let removed = snippets.removing(trigger: "firma")
        XCTAssertEqual(removed.items.count, 2)
        XCTAssertEqual(snippets.items.count, 3)
    }

    func testCodableRoundTrip() throws {
        let data = try JSONEncoder().encode(snippets)
        XCTAssertEqual(try JSONDecoder().decode(Snippets.self, from: data), snippets)
    }
}
