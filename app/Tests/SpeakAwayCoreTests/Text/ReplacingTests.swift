import XCTest
@testable import SpeakAwayCore

final class DictionaryReplacingTests: XCTestCase {
    private let alfa = DictionaryEntry(word: "Alfa")
    private let bravo = DictionaryEntry(word: "Bravo", replacing: ["bravó"])
    private let charlie = DictionaryEntry(word: "Charlie")

    func testAnEditedEntryKeepsItsPlace() {
        let edited = PersonalDictionary(entries: [alfa, bravo, charlie])
            .replacing(word: "Bravo", with: DictionaryEntry(word: "Bravo!", replacing: ["bravo", "brabo"]))
        XCTAssertEqual(edited.entries.map(\.word), ["Alfa", "Bravo!", "Charlie"])
        XCTAssertEqual(edited.entries[1].replacing, ["bravo", "brabo"])
    }

    func testTheOldWordIsFoundIgnoringCase() {
        let edited = PersonalDictionary(entries: [alfa, bravo]).replacing(word: "bravo", with: DictionaryEntry(word: "Bravo 2"))
        XCTAssertEqual(edited.entries.map(\.word), ["Alfa", "Bravo 2"])
    }

    func testRenamingOntoAnotherEntryKeepsOnlyTheEditedOne() {
        let edited = PersonalDictionary(entries: [alfa, bravo, charlie])
            .replacing(word: "Alfa", with: DictionaryEntry(word: "Charlie", replacing: ["charli"]))
        XCTAssertEqual(edited.entries.map(\.word), ["Charlie", "Bravo"])
        XCTAssertEqual(edited.entries[0].replacing, ["charli"])
    }

    func testAnUnknownOldWordJustAddsTheEntry() {
        let edited = PersonalDictionary(entries: [alfa]).replacing(word: "Zulu", with: bravo)
        XCTAssertEqual(edited.entries.map(\.word), ["Alfa", "Bravo"])
    }

    func testTheOriginalIsLeftAlone() {
        let original = PersonalDictionary(entries: [alfa, bravo])
        _ = original.replacing(word: "Alfa", with: DictionaryEntry(word: "Otro"))
        XCTAssertEqual(original.entries.map(\.word), ["Alfa", "Bravo"])
    }
}

final class SnippetsReplacingTests: XCTestCase {
    private let one = Snippet(trigger: "mi link", expansion: "https://example.com/carla")
    private let two = Snippet(trigger: "mi dirección", expansion: "Calle 50, Panamá")
    private let three = Snippet(trigger: "saludo", expansion: "Hola, gracias por escribir.")

    func testAnEditedSnippetKeepsItsPlace() {
        let edited = Snippets(items: [one, two, three])
            .replacing(trigger: "mi dirección", with: Snippet(trigger: "mi oficina", expansion: "Calle 50, piso 3"))
        XCTAssertEqual(edited.items.map(\.trigger), ["mi link", "mi oficina", "saludo"])
        XCTAssertEqual(edited.items[1].expansion, "Calle 50, piso 3")
    }

    func testTheOldTriggerIsFoundIgnoringCaseAndAccents() {
        let edited = Snippets(items: [one, two])
            .replacing(trigger: "MI DIRECCION", with: Snippet(trigger: "mi casa", expansion: "x"))
        XCTAssertEqual(edited.items.map(\.trigger), ["mi link", "mi casa"])
    }

    func testRenamingOntoAnotherTriggerKeepsOnlyTheEditedOne() {
        let edited = Snippets(items: [one, two, three])
            .replacing(trigger: "mi link", with: Snippet(trigger: "Saludo", expansion: "Nuevo"))
        XCTAssertEqual(edited.items.map(\.trigger), ["Saludo", "mi dirección"])
        XCTAssertEqual(edited.items[0].expansion, "Nuevo")
    }

    func testAnUnknownTriggerJustAddsTheSnippet() {
        let edited = Snippets(items: [one]).replacing(trigger: "nada", with: two)
        XCTAssertEqual(edited.items.map(\.trigger), ["mi link", "mi dirección"])
    }
}
