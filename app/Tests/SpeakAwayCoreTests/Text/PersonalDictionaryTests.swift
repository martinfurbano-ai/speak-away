import XCTest
@testable import SpeakAwayCore

final class PersonalDictionaryTests: XCTestCase {
    private let dict = PersonalDictionary(entries: [
        DictionaryEntry(word: "Helios", replacing: ["elios", "helios", "Eli os"]),
        DictionaryEntry(word: "Kubernetes", replacing: ["cuber netes", "cubernetes"]),
        DictionaryEntry(word: "Iuvenis", replacing: ["juvenis"]),
    ])

    func testReplacesMisheardFormCaseInsensitively() {
        XCTAssertEqual(dict.apply(to: "Hablé con ELIOS ayer"), "Hablé con Helios ayer")
    }

    func testKeepsSurroundingPunctuation() {
        XCTAssertEqual(dict.apply(to: "¿Viste Juvenis? Sí, juvenis."), "¿Viste Iuvenis? Sí, Iuvenis.")
    }

    func testOnlyWholeWords() {
        XCTAssertEqual(dict.apply(to: "Los eliosfilos y la melios"), "Los eliosfilos y la melios")
    }

    func testMultiWordMisheardForm() {
        XCTAssertEqual(dict.apply(to: "Deploy en cuber netes ya"), "Deploy en Kubernetes ya")
        XCTAssertEqual(dict.apply(to: "Deploy en cuber   netes ya"), "Deploy en Kubernetes ya")
    }

    func testSeveralReplacementsInOneText() {
        XCTAssertEqual(dict.apply(to: "juvenis usa cubernetes"), "Iuvenis usa Kubernetes")
    }

    func testLongerFormWinsOverShorterOverlap() {
        let d = PersonalDictionary(entries: [
            DictionaryEntry(word: "Open AI", replacing: ["open"]),
            DictionaryEntry(word: "OpenAI Codex", replacing: ["open ai codex"]),
        ])
        XCTAssertEqual(d.apply(to: "uso open ai codex hoy"), "uso OpenAI Codex hoy")
    }

    func testEmptyDictionaryAndEmptyTextAreUntouched() {
        XCTAssertEqual(PersonalDictionary().apply(to: "hola"), "hola")
        XCTAssertEqual(dict.apply(to: ""), "")
    }

    func testRegexCharactersInFormsAreLiteral() {
        let d = PersonalDictionary(entries: [DictionaryEntry(word: "C++", replacing: ["c plus plus", "c.+"])])
        XCTAssertEqual(d.apply(to: "escribo en c plus plus"), "escribo en C++")
        XCTAssertEqual(d.apply(to: "abc"), "abc")
    }

    func testAddingReturnsANewValue() {
        let original = PersonalDictionary()
        let added = original.adding(DictionaryEntry(word: "Dale", replacing: ["dali"]))
        XCTAssertEqual(original.entries.count, 0)
        XCTAssertEqual(added.entries.count, 1)
    }

    func testAddingSameWordReplacesTheEntry() {
        let a = dict.adding(DictionaryEntry(word: "helios", replacing: ["elyos"]))
        XCTAssertEqual(a.entries.count, 3)
        XCTAssertEqual(a.apply(to: "elyos"), "helios")
        XCTAssertEqual(dict.entries.count, 3)
    }

    func testRemovingReturnsANewValue() {
        let r = dict.removing(word: "kubernetes")
        XCTAssertEqual(r.entries.map(\.word), ["Helios", "Iuvenis"])
        XCTAssertEqual(dict.entries.count, 3)
    }

    func testWhisperPromptIsCommaSeparatedWords() {
        XCTAssertEqual(dict.whisperPrompt(limit: 100), "Helios, Kubernetes, Iuvenis")
    }

    func testWhisperPromptIsCapped() {
        XCTAssertEqual(dict.whisperPrompt(limit: 20), "Helios, Kubernetes")
        XCTAssertEqual(dict.whisperPrompt(limit: 5), "")
        XCTAssertEqual(dict.whisperPrompt(limit: 0), "")
    }

    func testWhisperPromptSkipsEmptyAndDuplicateWords() {
        let d = PersonalDictionary(entries: [
            DictionaryEntry(word: " ", replacing: []),
            DictionaryEntry(word: "Dale", replacing: []),
            DictionaryEntry(word: "Dale", replacing: ["dali"]),
        ])
        XCTAssertEqual(d.whisperPrompt(limit: 50), "Dale")
    }

    func testCodableRoundTrip() throws {
        let data = try JSONEncoder().encode(dict)
        XCTAssertEqual(try JSONDecoder().decode(PersonalDictionary.self, from: data), dict)
    }
}
