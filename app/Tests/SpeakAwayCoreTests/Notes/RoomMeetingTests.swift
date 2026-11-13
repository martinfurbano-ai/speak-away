import XCTest
@testable import SpeakAwayCore

/// A meeting recorded from one microphone has no "me" and "them": its lines belong to the room, and the
/// moments it stopped listening are markers. The note and the Mac's own meetings must keep reading the same.
final class RoomMeetingTests: XCTestCase {
    private let utc = TimeZone(identifier: "UTC")!
    private let start = Date(timeIntervalSince1970: 1_793_620_800) // 2026-11-02 12:00:00 UTC

    private func meeting(_ lines: [TranscriptLine], summary: String? = nil) -> Meeting {
        Meeting(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, title: "Revisión semanal", app: "iPhone",
                startedAt: start, endedAt: start.addingTimeInterval(600), lines: lines, summary: summary)
    }

    private func room(_ start: TimeInterval, _ text: String) -> TranscriptLine { TranscriptLine(speaker: .room, start: start, text: text) }
    private func marker(_ start: TimeInterval, _ text: String) -> TranscriptLine { TranscriptLine(speaker: .marker, start: start, text: text) }

    // MARK: The model

    func testTheNewSpeakersAreStoredByName() throws {
        let json = Meeting.ndjsonLine(for: room(12, "Hola"))
        XCTAssertTrue(json.contains("\"speaker\":\"room\""), json)
        XCTAssertTrue(Meeting.ndjsonLine(for: marker(12, "Pausa")).contains("\"speaker\":\"marker\""))
        let back = try JSONDecoder().decode(TranscriptLine.self, from: Data(json.utf8))
        XCTAssertEqual(back, room(12, "Hola"))
    }

    func testAMeetingWithRoomLinesSurvivesItsFile() throws {
        let original = meeting([room(3, "Hola"), marker(9, "Pausa"), room(20, "Seguimos")], summary: "S")
        let back = try Meeting.decoder.decode(Meeting.self, from: Meeting.encoder.encode(original))
        XCTAssertEqual(back, original)
    }

    func testMeetingsWrittenBeforeStillReadTheSame() throws {
        let old = Data(#"{"speaker":"them","start":4,"text":"Buenas"}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(TranscriptLine.self, from: old), TranscriptLine(speaker: .them, start: 4, text: "Buenas"))
    }

    func testALineAndAMarkerAtTheSameMomentAreDifferentRows() {
        XCTAssertNotEqual(room(5, "x").id, marker(5, "x").id)
    }

    // MARK: Turns

    func testRoomLinesStayAsTheParagraphsTheyWere() {
        let turns = Meeting.turns([room(0, "Primero."), room(30, "Segundo.")])
        XCTAssertEqual(turns.map(\.text), ["Primero.", "Segundo."])
        XCTAssertEqual(turns.map(\.start), [0, 30])
    }

    func testMarkersAreKeptBetweenTheLinesAroundThem() {
        let turns = Meeting.turns([room(40, "Después."), marker(20, "Pausa"), room(0, "Antes.")])
        XCTAssertEqual(turns.map(\.speaker), [.room, .marker, .room])
        XCTAssertEqual(turns.map(\.text), ["Antes.", "Pausa", "Después."])
    }

    func testEmptyRoomLinesAreDropped() {
        XCTAssertEqual(Meeting.turns([room(0, "  "), room(5, "Algo.")]).map(\.text), ["Algo."])
    }

    func testTheMacsMergingOfTheSameSpeakerIsUnchanged() {
        let turns = Meeting.turns([
            TranscriptLine(speaker: .me, start: 10, text: "Primero esto."),
            TranscriptLine(speaker: .me, start: 25, text: "Y luego aquello."),
            TranscriptLine(speaker: .them, start: 40, text: "Entendido."),
        ])
        XCTAssertEqual(turns.map(\.text), ["Primero esto. Y luego aquello.", "Entendido."])
    }

    // MARK: Markdown

    func testARoomLineShowsItsTimeAndNoSpeaker() {
        let md = meeting([room(192, "Hola a todos.")]).markdown(timeZone: utc)
        XCTAssertTrue(md.contains("**00:03:12** Hola a todos.\n"), md)
        XCTAssertFalse(md.contains("**Yo**"))
        XCTAssertFalse(md.contains("Ellos"))
    }

    func testAMarkerIsAnItalicLineWithItsTime() {
        let md = meeting([marker(75, "Pausa")]).markdown(timeZone: utc)
        XCTAssertTrue(md.contains("*00:01:15 Pausa*\n"), md)
    }

    func testTheEnglishNoteReadsTheSameForARoom() {
        XCTAssertEqual(meeting([room(5, "Hello.")]).markdown(timeZone: utc, english: true),
                       meeting([room(5, "Hello.")]).markdown(timeZone: utc, english: false))
    }

    func testTheWholeNoteKeepsTheOrderOfARecordedMeeting() {
        let md = meeting([room(0, "Antes."), marker(20, "Pausa"), room(40, "Después.")], summary: "Se decidió lanzar.")
            .markdown(timeZone: utc)
        let order = ["**00:00:00** Antes.", "*00:00:20 Pausa*", "**00:00:40** Después.", "## Resumen"].compactMap { md.range(of: $0)?.lowerBound }
        XCTAssertEqual(order.count, 4)
        XCTAssertEqual(order, order.sorted())
    }

    func testTheChatPromptCarriesTheRoomTranscript() {
        let prompt = meeting([room(5, "Revisamos el presupuesto.")]).chatPrompt(timeZone: utc)
        XCTAssertTrue(prompt.hasPrefix("Resume esta reunión en:"))
        XCTAssertTrue(prompt.contains("**00:00:05** Revisamos el presupuesto."))
    }

    func testNoEmDashesInARoomNote() {
        let md = meeting([room(1, "x"), marker(2, "y")], summary: "z").markdown(timeZone: utc)
        XCTAssertFalse(md.contains("\u{2014}"))
    }
}

final class MeetingTitleTests: XCTestCase {
    private let utc = TimeZone(identifier: "UTC")!
    private let start = Date(timeIntervalSince1970: 1_793_620_800 + 3 * 3600 + 30 * 60) // 2026-11-02 15:30 UTC

    func testAMeetingWithoutATitleIsNamedByItsTime() {
        XCTAssertEqual(MeetingTitle.resolved("", startedAt: start, english: false, timeZone: utc), "Reunión 15:30")
        XCTAssertEqual(MeetingTitle.resolved("", startedAt: start, english: true, timeZone: utc), "Meeting 15:30")
    }

    func testBlankTitlesCountAsNoTitle() {
        XCTAssertEqual(MeetingTitle.resolved("   \n ", startedAt: start, english: false, timeZone: utc), "Reunión 15:30")
    }

    func testATypedTitleIsKeptTrimmed() {
        XCTAssertEqual(MeetingTitle.resolved("  Comité de compras ", startedAt: start, english: false, timeZone: utc), "Comité de compras")
    }

    func testAnEnormousTitleIsCut() {
        let long = String(repeating: "a", count: 300)
        XCTAssertEqual(MeetingTitle.resolved(long, startedAt: start, english: false, timeZone: utc).count, MeetingTitle.maxLength)
    }

    func testNewLinesInTheTitleBecomeSpaces() {
        XCTAssertEqual(MeetingTitle.resolved("Plan\nQ4", startedAt: start, english: false, timeZone: utc), "Plan Q4")
    }
}
