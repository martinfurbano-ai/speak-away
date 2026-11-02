import XCTest
@testable import SpeakAwayCore

final class JSONFileStoreTests: XCTestCase {
    struct Sample: Codable, Equatable { var words: [String]; var when: Date }

    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("speakaway-tests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testMissingFileGivesTheDefault() {
        let store = JSONFileStore<Sample>(url: dir.appendingPathComponent("a.json"))
        XCTAssertEqual(store.load(default: Sample(words: ["x"], when: Date(timeIntervalSince1970: 0))).words, ["x"])
    }

    func testSaveCreatesFoldersAndRoundTrips() throws {
        let url = dir.appendingPathComponent("deep/er/a.json")
        let store = JSONFileStore<Sample>(url: url)
        let value = Sample(words: ["hola", "mundo"], when: Date(timeIntervalSince1970: 1_700_000_000))
        try store.save(value)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(JSONFileStore<Sample>(url: url).load(default: Sample(words: [], when: Date())), value)
    }

    func testSaveReplacesTheOldValue() throws {
        let store = JSONFileStore<[Int]>(url: dir.appendingPathComponent("n.json"))
        try store.save([1, 2, 3])
        try store.save([9])
        XCTAssertEqual(store.load(default: []), [9])
    }

    func testCorruptFileGivesTheDefaultAndIsKeptAsBackup() throws {
        let url = dir.appendingPathComponent("bad.json")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("{not json".utf8).write(to: url)
        let store = JSONFileStore<[Int]>(url: url)
        XCTAssertEqual(store.load(default: [7]), [7])
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.appendingPathExtension("bak").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testDeleteRemovesTheFile() throws {
        let store = JSONFileStore<[Int]>(url: dir.appendingPathComponent("n.json"))
        try store.save([1])
        store.delete()
        XCTAssertEqual(store.load(default: []), [])
    }
}
