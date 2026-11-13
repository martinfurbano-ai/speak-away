import XCTest
@testable import SpeakAwayCore

/// The file a meeting is written to as it is said, so a crash or a kill keeps everything said so far.
final class MeetingJournalTests: XCTestCase {
    private let id = UUID(uuidString: "5A5A0009-0000-4000-8000-000000000009")!
    private let started = Date(timeIntervalSince1970: 1_800_000_000)
    private var header: MeetingJournal.Header {
        MeetingJournal.Header(id: id, startedAt: started, app: "iPhone", title: "Weekly")
    }

    private func journal(_ entries: [MeetingJournal.Entry]) -> String {
        ([MeetingJournal.line(begin: header)] + entries.map(MeetingJournal.line(for:))).joined(separator: "\n") + "\n"
    }

    private func phrase(_ text: String, _ start: Double, _ end: Double) -> MeetingJournal.Entry {
        .phrase(RecognizedPhrase(text: text, start: start, end: end, isFinal: true))
    }

    func testEveryRecordIsOneLine() {
        XCTAssertFalse(MeetingJournal.line(begin: header).contains("\n"))
        XCTAssertFalse(MeetingJournal.line(for: phrase("Hola\ncon salto.", 0, 1)).contains("\n"))
        XCTAssertFalse(MeetingJournal.line(for: .marker(start: 3, text: "Pausa")).contains("\n"))
        XCTAssertFalse(MeetingJournal.line(for: .title("Un título")).contains("\n"))
    }

    func testARecoveredMeetingKeepsTheHeaderAndGroupsThePhrasesIntoParagraphs() throws {
        let text = journal([phrase("Hola.", 0, 2), phrase("Seguimos.", 3, 5), phrase("Otra cosa.", 20, 22)])
        let meeting = try XCTUnwrap(MeetingJournal.recover(from: text, lastActivity: started.addingTimeInterval(30),
                                                           endNote: "La grabación se cortó"))
        XCTAssertEqual(meeting.id, id)
        XCTAssertEqual(meeting.title, "Weekly")
        XCTAssertEqual(meeting.app, "iPhone")
        XCTAssertEqual(meeting.startedAt.timeIntervalSince1970, started.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(meeting.endedAt.timeIntervalSince1970, started.timeIntervalSince1970 + 30, accuracy: 1)
        XCTAssertEqual(meeting.lines, [
            TranscriptLine(speaker: .room, start: 0, text: "Hola. Seguimos."),
            TranscriptLine(speaker: .room, start: 20, text: "Otra cosa."),
            TranscriptLine(speaker: .marker, start: 30, text: "La grabación se cortó"),
        ])
        XCTAssertNil(meeting.summary)
    }

    func testTheLastTitleWins() throws {
        let text = journal([.title("Primero"), phrase("Hola a todos.", 0, 2), .title("Segundo")])
        let meeting = try XCTUnwrap(MeetingJournal.recover(from: text, lastActivity: started.addingTimeInterval(5), endNote: "Fin"))
        XCTAssertEqual(meeting.title, "Segundo")
    }

    func testMarkersAreKeptInOrder() throws {
        let text = journal([phrase("Antes.", 0, 2), .marker(start: 10, text: "Pausa"), phrase("Después.", 40, 42)])
        let meeting = try XCTUnwrap(MeetingJournal.recover(from: text, lastActivity: started.addingTimeInterval(50), endNote: "Fin"))
        XCTAssertEqual(meeting.lines.map(\.speaker), [.room, .marker, .room, .marker])
        XCTAssertEqual(meeting.lines.map(\.text), ["Antes.", "Pausa", "Después.", "Fin"])
    }

    func testATornLastLineIsIgnored() throws {
        let text = journal([phrase("Hola.", 0, 2)]) + "{\"kind\":\"phrase\",\"start\":4,\"te"
        let meeting = try XCTUnwrap(MeetingJournal.recover(from: text, lastActivity: started.addingTimeInterval(9), endNote: "Fin"))
        XCTAssertEqual(meeting.lines.map(\.text), ["Hola.", "Fin"])
    }

    func testWithoutAHeaderThereIsNoMeeting() {
        let text = MeetingJournal.line(for: phrase("Hola.", 0, 1)) + "\n"
        XCTAssertNil(MeetingJournal.recover(from: text, lastActivity: started, endNote: "Fin"))
        XCTAssertNil(MeetingJournal.recover(from: "", lastActivity: started, endNote: "Fin"))
    }

    func testAMeetingNobodySpokeInIsNotKept() {
        XCTAssertNil(MeetingJournal.recover(from: journal([]), lastActivity: started.addingTimeInterval(60), endNote: "Fin"))
        XCTAssertNil(MeetingJournal.recover(from: journal([.marker(start: 5, text: "Pausa")]),
                                            lastActivity: started.addingTimeInterval(60), endNote: "Fin"))
    }

    func testTheMeetingNeverEndsBeforeItsLastWords() throws {
        let text = journal([phrase("Muy tarde.", 600, 640)])
        let meeting = try XCTUnwrap(MeetingJournal.recover(from: text, lastActivity: started.addingTimeInterval(10), endNote: "Fin"))
        XCTAssertGreaterThanOrEqual(meeting.endedAt.timeIntervalSince(meeting.startedAt), 640)
    }

    func testQuotesAccentsAndEmojiSurviveTheFile() throws {
        let said = "Dijo «sí» y \"no\", con acento: canción 🎤 \\ barra."
        let text = journal([phrase(said, 0, 2)])
        let meeting = try XCTUnwrap(MeetingJournal.recover(from: text, lastActivity: started.addingTimeInterval(3), endNote: "Fin"))
        XCTAssertEqual(meeting.lines.first?.text, said)
    }

    func testTheEndNoteIsLeftOutWhenItIsEmpty() throws {
        let text = journal([phrase("Hola.", 0, 2)])
        let meeting = try XCTUnwrap(MeetingJournal.recover(from: text, lastActivity: started.addingTimeInterval(3), endNote: ""))
        XCTAssertEqual(meeting.lines.map(\.speaker), [.room])
    }

    func testTheNameOfTheFileIsTheOneTheStoreAlreadyIgnores() {
        // `NotesStore` lists `.json` files only, so the journal never shows up as a meeting.
        XCTAssertEqual(MeetingJournal.fileName, "live.ndjson")
    }
}
