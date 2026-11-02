import XCTest
@testable import SpeakAwayCore

final class HistoryTests: XCTestCase {
    private func item(_ text: String, app: String? = nil, at seconds: TimeInterval = 0) -> HistoryItem {
        HistoryItem(date: Date(timeIntervalSince1970: seconds), text: text, raw: text, app: app)
    }

    func testWordsAreCountedOnCreation() {
        XCTAssertEqual(item("Hola Carla, te mando la cotización.").words, 6)
    }

    func testSearchIgnoresCaseAndAccents() {
        let items = [item("Cotización para Ñandú S.A."), item("Reunión del lunes"), item("otra cosa", app: "Mail")]
        XCTAssertEqual(History.search(items, "COTIZACION").count, 1)
        XCTAssertEqual(History.search(items, "nandu").count, 1)
        XCTAssertEqual(History.search(items, "reunion lunes").count, 1)
        XCTAssertEqual(History.search(items, "mail").count, 1, "matches the app name too")
    }

    func testEmptyQueryReturnsEverythingAndNoMatchReturnsNothing() {
        let items = [item("uno"), item("dos")]
        XCTAssertEqual(History.search(items, "  ").count, 2)
        XCTAssertTrue(History.search(items, "zzz").isEmpty)
    }

    func testSearchAlsoLooksAtRawText() {
        let i = HistoryItem(date: Date(), text: "Hola.", raw: "eh hola este", app: nil)
        XCTAssertEqual(History.search([i], "este").count, 1)
    }

    func testAddingPutsNewestFirstAndCaps() {
        let a = item("a", at: 1), b = item("b", at: 2), c = item("c", at: 3)
        let list = History.adding(c, to: [b, a], cap: 2)
        XCTAssertEqual(list.map(\.text), ["c", "b"])
    }

    func testAddingDoesNotMutateTheInput() {
        let original = [item("a")]
        _ = History.adding(item("b"), to: original, cap: 5)
        XCTAssertEqual(original.count, 1)
    }

    func testDefaultCapIs2000() {
        XCTAssertEqual(History.cap, 2_000)
        let many = (0..<2_005).reduce([HistoryItem]()) { History.adding(item("n\($1)"), to: $0) }
        XCTAssertEqual(many.count, 2_000)
        XCTAssertEqual(many.first?.text, "n2004")
    }

    func testRemovingById() {
        let a = item("a"), b = item("b")
        XCTAssertEqual(History.removing(a.id, from: [a, b]).map(\.text), ["b"])
    }

    func testCodableRoundTrip() throws {
        let i = item("Hola", app: "Notes", at: 1_700_000_000)
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        XCTAssertEqual(try dec.decode(HistoryItem.self, from: enc.encode(i)), i)
    }
}
