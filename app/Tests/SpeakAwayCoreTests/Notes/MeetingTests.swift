import XCTest
@testable import SpeakAwayCore

final class MeetingTests: XCTestCase {
    let utc = TimeZone(identifier: "UTC")!
    let start = Date(timeIntervalSince1970: 1_793_620_800) // 2026-11-02 12:00:00 UTC

    func meeting(lines: [TranscriptLine], summary: String? = nil, title: String = "Revisión semanal") -> Meeting {
        Meeting(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: title,
            app: "Zoom",
            startedAt: start,
            endedAt: start.addingTimeInterval(1_932),
            lines: lines,
            summary: summary
        )
    }

    func testFrontmatter() {
        let md = meeting(lines: []).markdown(timeZone: utc)
        XCTAssertTrue(md.hasPrefix("---\ntitle: \"Revisión semanal\"\napp: Zoom\ndate: 2026-11-02 12:00\nduration: 00:32:12\n---\n"))
    }

    func testTitleIsEscapedInYAML() {
        let md = meeting(lines: [], title: "Plan \"Q4\" \\ equipo").markdown(timeZone: utc)
        XCTAssertTrue(md.contains("title: \"Plan \\\"Q4\\\" \\\\ equipo\""))
    }

    func testLinesUseSpeakerLabelsAndTimestamps() {
        let md = meeting(lines: [
            TranscriptLine(speaker: .me, start: 192, text: "Hola a todos."),
            TranscriptLine(speaker: .them, start: 200, text: "Buenas."),
        ]).markdown(timeZone: utc)
        XCTAssertTrue(md.contains("**Yo** 00:03:12 Hola a todos.\n"))
        XCTAssertTrue(md.contains("**Ellos** 00:03:20 Buenas.\n"))
    }

    func testSameSpeakerContinuingIsMerged() {
        let md = meeting(lines: [
            TranscriptLine(speaker: .me, start: 10, text: "Primero esto."),
            TranscriptLine(speaker: .me, start: 25, text: "Y luego aquello."),
            TranscriptLine(speaker: .them, start: 40, text: "Entendido."),
            TranscriptLine(speaker: .me, start: 50, text: "Listo."),
        ]).markdown(timeZone: utc)
        XCTAssertTrue(md.contains("**Yo** 00:00:10 Primero esto. Y luego aquello.\n"))
        XCTAssertEqual(md.components(separatedBy: "**Yo**").count - 1, 2)
        XCTAssertFalse(md.contains("00:00:25"))
    }

    func testLinesAreOrderedByTimeAcrossTracks() {
        let md = meeting(lines: [
            TranscriptLine(speaker: .them, start: 30, text: "B"),
            TranscriptLine(speaker: .me, start: 5, text: "A"),
        ]).markdown(timeZone: utc)
        XCTAssertLessThan(md.range(of: "A")!.lowerBound, md.range(of: "**Ellos**")!.lowerBound)
    }

    func testNoSummarySectionByDefault() {
        XCTAssertFalse(meeting(lines: []).markdown(timeZone: utc).contains("Resumen"))
        XCTAssertFalse(meeting(lines: [], summary: "  ").markdown(timeZone: utc).contains("Resumen"))
    }

    func testSummarySection() {
        let md = meeting(lines: [], summary: "Se decidió lanzar.").markdown(timeZone: utc)
        XCTAssertTrue(md.contains("## Resumen\n\nSe decidió lanzar."))
    }

    func testNoEmDashesInOutput() {
        let md = meeting(lines: [TranscriptLine(speaker: .me, start: 1, text: "x")], summary: "y").markdown(timeZone: utc)
        XCTAssertFalse(md.contains("\u{2014}"))
    }

    func testDurationAndTimestampFormat() {
        XCTAssertEqual(Meeting.clock(0), "00:00:00")
        XCTAssertEqual(Meeting.clock(3_725.9), "01:02:05")
        XCTAssertEqual(Meeting.clock(-4), "00:00:00")
        XCTAssertEqual(meeting(lines: []).duration, 1_932, accuracy: 0.001)
    }

    func testNdjsonLineIsOneLineWithoutNewlines() throws {
        let line = TranscriptLine(speaker: .them, start: 12.5, text: "Hola\ncomo \"estás\" / bien")
        let json = Meeting.ndjsonLine(for: line)
        XCTAssertFalse(json.contains("\n"))
        let back = try JSONDecoder().decode(TranscriptLine.self, from: Data(json.utf8))
        XCTAssertEqual(back, line)
        XCTAssertTrue(json.contains("\"speaker\":\"them\""))
    }

    func testCodableRoundTrip() throws {
        let original = meeting(lines: [TranscriptLine(speaker: .me, start: 3, text: "Hola")], summary: "S")
        let data = try Meeting.encoder.encode(original)
        let back = try Meeting.decoder.decode(Meeting.self, from: data)
        XCTAssertEqual(back, original)
    }

    func testFileBaseSanitisesTheTitle() {
        let m = meeting(lines: [], title: "Cliente: A/B? <plan>")
        XCTAssertEqual(m.fileBase(timeZone: utc), "2026-11-02 Cliente A B plan")
        XCTAssertEqual(meeting(lines: [], title: "  ").fileBase(timeZone: utc), "2026-11-02 Reunión")
    }

    func testWithMethodsReturnNewValues() {
        let m = meeting(lines: [])
        let n = m.withSummary("S").appending(TranscriptLine(speaker: .me, start: 1, text: "a"))
        XCTAssertNil(m.summary)
        XCTAssertTrue(m.lines.isEmpty)
        XCTAssertEqual(n.summary, "S")
        XCTAssertEqual(n.lines.count, 1)
    }
}
