import XCTest
@testable import SpeakAwayCore

final class TextChunkerTests: XCTestCase {
    func testShortTextIsOneChunk() {
        XCTAssertEqual(TextChunker.chunks("Hola. Adiós.", maxChars: 100), ["Hola. Adiós."])
    }

    func testEmptyTextHasNoChunks() {
        XCTAssertEqual(TextChunker.chunks("  \n ", maxChars: 100), [])
    }

    func testSplitsAtSentenceBoundariesAndKeepsEverything() {
        let text = "Uno dos tres. Cuatro cinco seis. Siete ocho nueve. Diez once doce."
        let chunks = TextChunker.chunks(text, maxChars: 35)
        XCTAssertGreaterThan(chunks.count, 1)
        XCTAssertTrue(chunks.allSatisfy { $0.count <= 35 })
        XCTAssertEqual(chunks.joined(separator: " "), text)
        XCTAssertTrue(chunks.dropLast().allSatisfy { $0.hasSuffix(".") })
    }

    func testPrefersLineBreaksForTranscripts() {
        let text = "Ana: hola a todos\nLuis: buenas\nAna: empecemos"
        let chunks = TextChunker.chunks(text, maxChars: 30)
        XCTAssertEqual(chunks, ["Ana: hola a todos\nLuis: buenas", "Ana: empecemos"])
    }

    func testHardSplitsAGiantWordlessRun() {
        let chunks = TextChunker.chunks(String(repeating: "a", count: 25), maxChars: 10)
        XCTAssertEqual(chunks.map(\.count), [10, 10, 5])
    }

    func testLongSentenceFallsBackToWords() {
        let text = (1...12).map { "palabra\($0)" }.joined(separator: " ")
        let chunks = TextChunker.chunks(text, maxChars: 30)
        XCTAssertTrue(chunks.allSatisfy { $0.count <= 30 })
        XCTAssertEqual(chunks.joined(separator: " "), text)
    }

    func testGroupsPackWholeItemsInOrder() {
        let groups = TextChunker.groups(["aaaa", "bbbb", "cccc", "dd"], maxChars: 14)
        XCTAssertEqual(groups, [["aaaa", "bbbb"], ["cccc", "dd"]])
    }

    func testGroupsPutAnOversizedItemAloneAndDropBlanks() {
        let groups = TextChunker.groups(["a", " ", String(repeating: "z", count: 30), "b"], maxChars: 10)
        XCTAssertEqual(groups, [["a"], [String(repeating: "z", count: 30)], ["b"]])
        XCTAssertEqual(TextChunker.groups([], maxChars: 10), [])
    }
}
