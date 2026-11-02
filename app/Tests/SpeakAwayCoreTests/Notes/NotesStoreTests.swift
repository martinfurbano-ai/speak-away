import XCTest
@testable import SpeakAwayCore

final class NotesStoreTests: XCTestCase {
    var folder: URL!
    var store: NotesStore!
    let utc = TimeZone(identifier: "UTC")!

    override func setUp() {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("notes-\(UUID().uuidString)", isDirectory: true)
        store = NotesStore(folder: folder, timeZone: utc)
    }

    override func tearDown() { try? FileManager.default.removeItem(at: folder) }

    func make(_ title: String, at seconds: TimeInterval = 1_793_620_800) -> Meeting {
        Meeting(
            id: UUID(), title: title, app: "Zoom",
            startedAt: Date(timeIntervalSince1970: seconds), endedAt: Date(timeIntervalSince1970: seconds + 60),
            lines: [TranscriptLine(speaker: .me, start: 1, text: "Hola")], summary: nil
        )
    }

    func testDefaultFolderIsInsideApplicationSupport() {
        let path = NotesStore.defaultFolder.path
        XCTAssertTrue(path.hasSuffix("Speak Away/Meetings"), path)
        XCTAssertTrue(path.contains("Application Support"), path)
    }

    func testSaveWritesMarkdownAndJSONSideBySide() throws {
        let m = make("Cliente")
        let md = try store.save(m)
        XCTAssertEqual(md.lastPathComponent, "2026-11-02 Cliente.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("2026-11-02 Cliente.json").path))
        XCTAssertTrue(try String(contentsOf: md, encoding: .utf8).contains("**Yo** 00:00:01 Hola"))
    }

    func testLoadAndList() throws {
        let a = make("A", at: 1_793_620_800)
        let b = make("B", at: 1_793_707_200)
        _ = try store.save(a); _ = try store.save(b)
        XCTAssertEqual(store.load(a.id), a)
        XCTAssertEqual(store.list().map(\.id), [b.id, a.id])
        XCTAssertNil(store.load(UUID()))
    }

    func testSameTitleSameDayDoesNotOverwrite() throws {
        let a = make("Daily"), b = make("Daily")
        let first = try store.save(a), second = try store.save(b)
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(store.list().count, 2)
    }

    func testResavingKeepsOneCopyEvenWhenTheTitleChanges() throws {
        let a = make("Viejo")
        _ = try store.save(a)
        let renamed = Meeting(id: a.id, title: "Nuevo", app: a.app, startedAt: a.startedAt, endedAt: a.endedAt, lines: a.lines, summary: "S")
        _ = try store.save(renamed)
        XCTAssertEqual(store.list().count, 1)
        XCTAssertEqual(store.load(a.id)?.title, "Nuevo")
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        XCTAssertEqual(files, ["2026-11-02 Nuevo.json", "2026-11-02 Nuevo.md"])
    }

    func testDelete() throws {
        let a = make("A")
        _ = try store.save(a)
        store.delete(a.id)
        XCTAssertNil(store.load(a.id))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), [])
    }

    func testListIgnoresLiveFileAndGarbage() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "{}".write(to: store.liveFile, atomically: true, encoding: .utf8)
        try "no json".write(to: folder.appendingPathComponent("x.json"), atomically: true, encoding: .utf8)
        XCTAssertEqual(store.list(), [])
    }

    func testLiveFileLivesInTheFolder() {
        XCTAssertEqual(store.liveFile.lastPathComponent, "live.ndjson")
        XCTAssertEqual(store.liveFile.deletingLastPathComponent().path, folder.path)
    }
}
