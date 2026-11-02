import XCTest
@testable import SpeakAwayCore

final class ScratchNoteTests: XCTestCase {
    private let id = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    private let t1 = Date(timeIntervalSince1970: 1_700_000_000)
    private let t2 = Date(timeIntervalSince1970: 1_700_003_600)

    func testMarkdownRoundTrip() throws {
        let note = ScratchNote(id: id, created: t1, updated: t2, text: "Comprar leche\n\n- huevos\n- pan")
        let parsed = try XCTUnwrap(ScratchNote.parse(note.markdown()))
        XCTAssertEqual(parsed, note)
    }

    func testTextThatLooksLikeFrontMatterSurvives() throws {
        let note = ScratchNote(id: id, created: t1, updated: t1, text: "---\nid: x\n---\ncuerpo")
        XCTAssertEqual(try XCTUnwrap(ScratchNote.parse(note.markdown())).text, "---\nid: x\n---\ncuerpo")
    }

    func testPlainMarkdownWithoutFrontMatterStillLoads() throws {
        let note = try XCTUnwrap(ScratchNote.parse("hola\notra línea", fallbackID: id, fallbackDate: t1))
        XCTAssertEqual(note.text, "hola\notra línea")
        XCTAssertEqual(note.id, id)
        XCTAssertEqual(note.created, t1)
    }

    func testTitleIsTheFirstNonEmptyLineTrimmed() {
        XCTAssertEqual(ScratchNote(id: id, created: t1, updated: t1, text: "\n\n  Ideas de reels \nresto").title, "Ideas de reels")
        XCTAssertEqual(ScratchNote(id: id, created: t1, updated: t1, text: "").title, "Nota vacía")
        let long = ScratchNote(id: id, created: t1, updated: t1, text: String(repeating: "a", count: 200)).title
        XCTAssertEqual(long.count, 60)
    }

    func testWithTextReturnsANewNote() {
        let note = ScratchNote(id: id, created: t1, updated: t1, text: "a")
        let changed = note.withText("b", at: t2)
        XCTAssertEqual(note.text, "a")
        XCTAssertEqual(changed.text, "b")
        XCTAssertEqual(changed.updated, t2)
        XCTAssertEqual(changed.created, t1)
        XCTAssertEqual(changed.id, id)
    }
}

final class ScratchNotesFolderTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("speakaway-notes-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    func testOneMarkdownFilePerNoteNewestFirst() throws {
        let folder = ScratchNotesFolder(directory: dir)
        let old = ScratchNote(id: UUID(), created: Date(timeIntervalSince1970: 100), updated: Date(timeIntervalSince1970: 100), text: "vieja")
        let new = ScratchNote(id: UUID(), created: Date(timeIntervalSince1970: 200), updated: Date(timeIntervalSince1970: 300), text: "nueva")
        try folder.save(old)
        try folder.save(new)
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasSuffix(".md") }
        XCTAssertEqual(files.count, 2)
        XCTAssertEqual(folder.loadAll().map(\.text), ["nueva", "vieja"])
    }

    func testSavingTheSameNoteTwiceKeepsOneFile() throws {
        let folder = ScratchNotesFolder(directory: dir)
        let note = ScratchNote(id: UUID(), created: Date(), updated: Date(), text: "a")
        try folder.save(note)
        try folder.save(note.withText("b", at: Date()))
        XCTAssertEqual(folder.loadAll().map(\.text), ["b"])
    }

    func testDeleteAndIgnoresOtherFiles() throws {
        let folder = ScratchNotesFolder(directory: dir)
        let note = ScratchNote(id: UUID(), created: Date(), updated: Date(), text: "a")
        try folder.save(note)
        try Data("x".utf8).write(to: dir.appendingPathComponent("notes.txt"))
        XCTAssertEqual(folder.loadAll().count, 1)
        folder.delete(note.id)
        XCTAssertTrue(folder.loadAll().isEmpty)
    }

    func testMissingFolderLoadsEmpty() {
        XCTAssertTrue(ScratchNotesFolder(directory: dir).loadAll().isEmpty)
    }
}
