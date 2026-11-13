import XCTest
@testable import SpeakAwayCore

final class MeetingSummaryTests: XCTestCase {
    private let sample = MeetingSummary(
        summary: "Se acordó lanzar el lunes.",
        decisions: ["Lanzar el lunes"],
        actionItems: ["Ana envía el comunicado", "Luis revisa el precio"],
        questions: ["¿Quién avisa a prensa?"]
    )

    func testMarkdownHasAllSections() {
        let md = sample.markdown()
        XCTAssertTrue(md.contains("## Resumen\n\nSe acordó lanzar el lunes."))
        XCTAssertTrue(md.contains("## Decisiones\n\n- Lanzar el lunes"))
        XCTAssertTrue(md.contains("## Tareas\n\n- [ ] Ana envía el comunicado\n- [ ] Luis revisa el precio"))
        XCTAssertTrue(md.contains("## Preguntas abiertas\n\n- ¿Quién avisa a prensa?"))
    }

    func testMarkdownSkipsEmptySectionsAndCanBeEnglish() {
        let s = MeetingSummary(summary: "Short.", decisions: [], actionItems: [], questions: [])
        XCTAssertEqual(s.markdown(), "## Resumen\n\nShort.\n")
        XCTAssertTrue(sample.markdown(english: true).contains("## Action items"))
    }

    func testIsEmpty() {
        XCTAssertTrue(MeetingSummary(summary: " ", decisions: [], actionItems: [], questions: []).isEmpty)
        XCTAssertFalse(sample.isEmpty)
    }

    func testCodableRoundTrip() throws {
        let data = try JSONEncoder().encode(sample)
        XCTAssertEqual(try JSONDecoder().decode(MeetingSummary.self, from: data), sample)
    }

    func testMergingDedupesIgnoringCaseAndAccentsAndKeepsOrder() {
        let a = MeetingSummary(summary: "A", decisions: ["Lanzar el lunes"], actionItems: ["Enviar comunicado"], questions: [])
        let b = MeetingSummary(summary: "B", decisions: ["lanzar el lunes", "Subir precio"], actionItems: ["enviar comunicádo"], questions: ["¿Quién?"])
        let merged = MeetingSummary.merging([a, b], summary: "Todo")
        XCTAssertEqual(merged.summary, "Todo")
        XCTAssertEqual(merged.decisions, ["Lanzar el lunes", "Subir precio"])
        XCTAssertEqual(merged.actionItems, ["Enviar comunicado"])
        XCTAssertEqual(merged.questions, ["¿Quién?"])
        XCTAssertEqual(a.decisions, ["Lanzar el lunes"])
    }

    func testCleaningDropsBlanksAndTrims() {
        let s = MeetingSummary(summary: " Hola \n", decisions: ["  ", " x "], actionItems: [], questions: [""]).cleaned()
        XCTAssertEqual(s.summary, "Hola")
        XCTAssertEqual(s.decisions, ["x"])
        XCTAssertEqual(s.questions, [])
    }
}

final class BrainAvailabilityTests: XCTestCase {
    func testMessagesAreSpanishAndOnlyAvailableIsUsable() {
        XCTAssertTrue(BrainAvailability.available.isUsable)
        XCTAssertFalse(BrainAvailability.needsAppleIntelligence.isUsable)
        XCTAssertFalse(BrainAvailability.unsupportedOS.isUsable)
        XCTAssertTrue(BrainAvailability.needsAppleIntelligence.message.contains("Apple Intelligence"))
        XCTAssertTrue(BrainAvailability.unsupportedOS.message.contains("26"))
        XCTAssertEqual(BrainAvailability.available.message, "")
    }

    /// The same words are shown on the Mac and on the iPhone, so they name neither.
    func testMessagesNameNoParticularDevice() {
        let statuses: [BrainAvailability] = [.needsAppleIntelligence, .unsupportedOS, .deviceNotEligible, .modelNotReady]
        for status in statuses {
            for word in ["Mac", "macOS", "iPhone", "iOS", "Ajustes del Sistema"] {
                XCTAssertFalse(status.message.contains(word), "\(status) mentions \(word)")
            }
            XCTAssertFalse(status.message.isEmpty, "\(status)")
        }
        XCTAssertFalse((BrainError.tooLong.errorDescription ?? "").contains("Mac"))
    }

    func testBrainErrorDescriptions() {
        XCTAssertEqual(BrainError.unavailable(.unsupportedOS).errorDescription, BrainAvailability.unsupportedOS.message)
        XCTAssertEqual(BrainError.tooLong.errorDescription, "El texto es demasiado largo para el modelo del dispositivo.")
        XCTAssertEqual(BrainError.failed("x").errorDescription, "x")
    }
}
