import XCTest
@testable import SpeakAwayCore

final class TextPipelineTests: XCTestCase {
    private let dictionary = PersonalDictionary(entries: [
        DictionaryEntry(word: "Iuvenis", replacing: ["juvenis", "iuvenes"]),
        DictionaryEntry(word: "Helios", replacing: ["elios"]),
    ])
    private let snippets = Snippets(items: [
        Snippet(trigger: "mi link de calendario", expansion: "https://cal.com/martin"),
        Snippet(trigger: "my signature", expansion: "Best regards,\nMartin"),
    ])

    private func run(_ raw: String, language: String? = "es", style: WritingStyle = .formal, autoEdit: Bool = true) -> String {
        TextPipeline.process(raw: raw, language: language, dictionary: dictionary, snippets: snippets, style: style, autoEdit: autoEdit)
    }

    func testDictionaryRunsBeforeAutoEdit() {
        XCTAssertEqual(run("eh la clínica juvenis abre hoy"), "La clínica Iuvenis abre hoy.")
    }

    func testAutoEditCanBeSwitchedOff() {
        XCTAssertEqual(run("eh hola eh mundo", autoEdit: false), "eh hola eh mundo.")
        XCTAssertEqual(run("eh hola eh mundo", autoEdit: true), "Hola mundo.")
    }

    func testSnippetsRunAfterAutoEdit() {
        XCTAssertEqual(run("eh agenda en mi link de calendario", style: .formal), "Agenda en https://cal.com/martin.")
    }

    func testStyleRunsLast() {
        XCTAssertEqual(run("Nos vemos mañana", style: .casual), "Nos vemos mañana")
        XCTAssertEqual(run("Nos vemos mañana", style: .veryCasual), "nos vemos mañana")
        XCTAssertEqual(run("Nos vemos mañana", style: .formal), "Nos vemos mañana.")
    }

    func testWholeUtteranceSnippetIsInsertedVerbatim() {
        XCTAssertEqual(run("Mi link de calendario.", style: .veryCasual), "https://cal.com/martin")
        XCTAssertEqual(run("My signature.", language: "en", style: .veryCasual), "Best regards,\nMartin")
        XCTAssertEqual(run("My signature.", language: "en", style: .formal), "Best regards,\nMartin")
    }

    func testBacktrackingThenStyleInEnglish() {
        XCTAssertEqual(run("um let's meet at 2, actually 3.", language: "en", style: .casual), "Let's meet at 3")
    }

    func testTrailingSpaceFromSpeechGateIsKept() {
        XCTAssertEqual(run("hola mundo ", style: .formal), "Hola mundo. ")
        XCTAssertEqual(run("hola mundo ", style: .formal, autoEdit: false), "hola mundo. ")
    }

    func testEmptyInput() {
        XCTAssertEqual(run(""), "")
        XCTAssertEqual(run("  "), "  ")
    }

    func testCompositionMatchesManualOrder() {
        let raw = "eh hola, juvenis aquí, perdón, helios"
        let manual = Style.apply(
            snippets.expand(AutoEdit.clean(dictionary.apply(to: raw), language: "es")),
            style: .formal)
        XCTAssertEqual(run(raw), manual)
    }
}
