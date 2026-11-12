import XCTest
@testable import SpeakAwayCore

final class DictationFlowTests: XCTestCase {
    private let dictionary = PersonalDictionary(entries: [DictionaryEntry(word: "Iuvenis", replacing: ["juvenis"])])
    private let snippets = Snippets(items: [Snippet(trigger: "my signature", expansion: "Best regards,\nMartin")])

    private func prepare(_ transcript: String, language: String? = "en-US", field: FieldContext = .general,
                         autoEdit: Bool = true) -> PreparedDictation? {
        DictationFlow.prepare(transcript: transcript, language: language, field: field, dictionary: dictionary,
                              snippets: snippets, styles: StyleSettings(), autoEdit: autoEdit)
    }

    func testMessagesGetTheCasualStyle() {
        let result = prepare("um let's meet tomorrow.")
        XCTAssertEqual(result?.style, .casual)
        XCTAssertEqual(result?.text, "Let's meet tomorrow ")
        XCTAssertEqual(result?.raw, "um let's meet tomorrow. ")
    }

    func testEmailFieldsGetTheFormalStyle() {
        let result = prepare("let's meet tomorrow", field: FieldContext(kind: .email))
        XCTAssertEqual(result?.style, .formal)
        XCTAssertEqual(result?.text, "Let's meet tomorrow. ")
    }

    func testTheKeyboardsStyleOverrideWinsOverTheFieldCategory() {
        let result = prepare("Let's meet tomorrow", field: FieldContext(kind: .email, styleOverride: .veryCasual))
        XCTAssertEqual(result?.style, .veryCasual)
        XCTAssertEqual(result?.text, "let's meet tomorrow ")
    }

    func testTheDictionaryAndBacktrackingRun() {
        let result = prepare("um the juvenis clinic opens at 2, actually 3.", field: FieldContext(kind: .email))
        XCTAssertEqual(result?.text, "The Iuvenis clinic opens at 3. ")
    }

    func testAutoEditCanBeOff() {
        let result = prepare("um hello", autoEdit: false)
        XCTAssertEqual(result?.text.contains("um"), true)
    }

    func testASnippetOnlyDictationIsInsertedAsWritten() {
        let result = prepare("My signature.", field: FieldContext(kind: .general, styleOverride: .veryCasual))
        XCTAssertEqual(result?.text, "Best regards,\nMartin ")
    }

    func testNoiseAndEmptyTranscriptsGiveNothing() {
        XCTAssertNil(prepare(""))
        XCTAssertNil(prepare("   "))
        XCTAssertNil(prepare("[BLANK_AUDIO]"))
        XCTAssertNil(prepare("(music)"))
    }

    func testTheTextKeepsTheSingleTrailingSpaceSoTheNextDictationDoesNotGlue() {
        let result = prepare("hello world")
        XCTAssertEqual(result?.text.hasSuffix(" "), true)
        XCTAssertEqual(result?.text.hasSuffix("  "), false)
    }

    func testTheWholeSentenceIsKeptWhenTheLanguageIsUnknown() {
        XCTAssertEqual(prepare("hola mundo", language: nil)?.text, "Hola mundo ")
    }

    func testSpanishLocaleIdentifiersSelectSpanishRules() {
        let result = prepare("eh hola eh mundo", language: "es-MX", field: FieldContext(kind: .email))
        XCTAssertEqual(result?.text, "Hola mundo. ")
    }
}
