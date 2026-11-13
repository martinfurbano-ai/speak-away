import XCTest
@testable import SpeakAwayCore

final class MeetingSummaryParseTests: XCTestCase {
    private let full = MeetingSummary(
        summary: "Se acordó el calendario del lanzamiento.\n\nCarla Ruiz presentó las cifras.",
        decisions: ["Lanzar el 3 de diciembre", "Mantener el precio"],
        actionItems: ["Carla envía el contrato el lunes", "Tomás revisa el presupuesto"],
        questions: ["¿Quién paga el envío?"])

    func testTheSavedMarkdownReadsBackAsTheSameNotes() {
        XCTAssertEqual(MeetingSummary(markdown: full.markdown()), full)
    }

    func testTheEnglishMarkdownReadsBackToo() {
        XCTAssertEqual(MeetingSummary(markdown: full.markdown(english: true)), full)
    }

    func testPendientesIsAnotherNameForTheActionItems() {
        let text = "## Resumen\n\nHola.\n\n## Pendientes\n\n- Llamar a Carla\n- [ ] Enviar la factura\n"
        XCTAssertEqual(MeetingSummary(markdown: text)?.actionItems, ["Llamar a Carla", "Enviar la factura"])
    }

    func testTickedAndStarredBulletsLoseTheirMarks() {
        let text = "## Decisions\n\n* First\n- [x] Second\n• Third\n"
        XCTAssertEqual(MeetingSummary(markdown: text)?.decisions, ["First", "Second", "Third"])
    }

    func testHeadingsIgnoreCaseAccentsAndDepth() {
        let text = "### RESUMEN\n\nTodo bien.\n\n# preguntas abiertas\n\n- ¿Y ahora?\n"
        let notes = MeetingSummary(markdown: text)
        XCTAssertEqual(notes?.summary, "Todo bien.")
        XCTAssertEqual(notes?.questions, ["¿Y ahora?"])
    }

    func testSectionsThatAreMissingAreEmpty() {
        let notes = MeetingSummary(markdown: "## Resumen\n\nSolo esto.\n")
        XCTAssertEqual(notes?.summary, "Solo esto.")
        XCTAssertEqual(notes?.decisions, [])
        XCTAssertEqual(notes?.actionItems, [])
        XCTAssertEqual(notes?.questions, [])
    }

    func testASectionWeDoNotKnowIsLeftOut() {
        let text = "## Resumen\n\nA.\n\n## Otros\n\n- no va\n\n## Decisiones\n\n- sí va\n"
        let notes = MeetingSummary(markdown: text)
        XCTAssertEqual(notes?.summary, "A.")
        XCTAssertEqual(notes?.decisions, ["sí va"])
    }

    func testTextWithoutKnownHeadingsIsNotNotes() {
        XCTAssertNil(MeetingSummary(markdown: "Una sola frase suelta."))
        XCTAssertNil(MeetingSummary(markdown: ""))
        XCTAssertNil(MeetingSummary(markdown: "## Otros\n\n- nada\n"))
    }

    func testSummaryParagraphsKeepTheirBlankLine() {
        let notes = MeetingSummary(markdown: "## Resumen\n\nUno.\n\nDos.\n")
        XCTAssertEqual(notes?.summary, "Uno.\n\nDos.")
    }
}

final class MeetingChatTests: XCTestCase {
    private func meeting() -> Meeting {
        Meeting(title: "Reunión con Carla Ruiz", app: "Zoom",
                startedAt: Date(timeIntervalSince1970: 1_800_000_000), endedAt: Date(timeIntervalSince1970: 1_800_000_600),
                lines: [TranscriptLine(speaker: .me, start: 0, text: "Hola Carla"),
                        TranscriptLine(speaker: .them, start: 5, text: "Hola, empecemos")])
    }

    func testTheSpanishPromptIsTheOneTheMacUses() {
        let m = meeting()
        let prompt = "Resume esta reunión en: Resumen, Decisiones, Pendientes (quién, qué, cuándo) y Preguntas abiertas.\n\n"
        XCTAssertEqual(m.chatPrompt(), prompt + m.markdown())
    }

    func testTheEnglishPromptAsksInEnglishAndLabelsTheSpeakersInEnglish() {
        let m = meeting()
        let text = m.chatPrompt(english: true)
        XCTAssertTrue(text.hasPrefix("Summarize this meeting as: Summary, Decisions, Action items (who, what, when) and Open questions.\n\n"))
        XCTAssertTrue(text.contains("**Me** 00:00:00 Hola Carla"))
        XCTAssertTrue(text.contains("**Them** 00:00:05 Hola, empecemos"))
        XCTAssertFalse(text.contains("**Yo**"))
    }

    func testTheSpanishMarkdownIsUnchanged() {
        let text = meeting().markdown()
        XCTAssertTrue(text.contains("**Yo** 00:00:00 Hola Carla"))
        XCTAssertTrue(text.contains("**Ellos** 00:00:05 Hola, empecemos"))
    }

    func testEnglishMarkdownNamesTheSummarySectionInEnglish() {
        let m = meeting().withSummary("Short recap.")
        XCTAssertTrue(m.markdown(english: true).contains("## Summary\n\nShort recap."))
        XCTAssertTrue(m.markdown().contains("## Resumen\n\nShort recap."))
    }
}
