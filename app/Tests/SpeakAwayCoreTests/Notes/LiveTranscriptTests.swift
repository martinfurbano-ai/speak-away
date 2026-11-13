import XCTest
@testable import SpeakAwayCore

/// How the results of the speech engine become the transcript: finalized phrases are kept, volatile text is only
/// what is on screen until the engine settles on it.
final class LiveTranscriptTests: XCTestCase {
    private func phrase(_ text: String, _ start: Double, _ end: Double, final: Bool = true) -> RecognizedPhrase {
        RecognizedPhrase(text: text, start: start, end: end, isFinal: final)
    }

    func testAFinalPhraseBecomesALineOfTheRoom() {
        let transcript = LiveTranscript().applying(phrase("Buenos días a todos.", 2, 4))
        XCTAssertEqual(transcript.lines, [TranscriptLine(speaker: .room, start: 2, text: "Buenos días a todos.")])
        XCTAssertEqual(transcript.volatile, "")
    }

    func testVolatileTextReplacesThePreviousVolatileTextAndIsNotKept() {
        let transcript = LiveTranscript()
            .applying(phrase("buenos", 0, 1, final: false))
            .applying(phrase("buenos días", 0, 1.5, final: false))
        XCTAssertEqual(transcript.volatile, "buenos días")
        XCTAssertTrue(transcript.lines.isEmpty)
    }

    func testAFinalPhraseClearsTheVolatileTextItAnswers() {
        let transcript = LiveTranscript()
            .applying(phrase("buenos dí", 0, 1.2, final: false))
            .applying(phrase("Buenos días.", 0, 1.5))
        XCTAssertEqual(transcript.volatile, "")
        XCTAssertEqual(transcript.lines.count, 1)
    }

    func testVolatileTextThatStartsWhereAFinalPhraseEndsSurvivesIt() {
        let transcript = LiveTranscript()
            .applying(phrase("segu", 2, 3, final: false))
            .applying(phrase("Primero.", 0, 2))
        XCTAssertEqual(transcript.volatile, "segu")
        XCTAssertEqual(transcript.lines.map(\.text), ["Primero."])
    }

    func testPhrasesCloseInTimeJoinTheSameParagraph() {
        let transcript = LiveTranscript()
            .applying(phrase("Empezamos.", 0, 2))
            .applying(phrase("Primer punto.", 3, 5))
        XCTAssertEqual(transcript.lines, [TranscriptLine(speaker: .room, start: 0, text: "Empezamos. Primer punto.")])
    }

    func testALongPauseStartsANewParagraph() {
        let transcript = LiveTranscript()
            .applying(phrase("Empezamos.", 0, 2))
            .applying(phrase("Segundo tema.", 2 + LiveTranscript.paragraphGap + 1, 12))
        XCTAssertEqual(transcript.lines.map(\.start), [0, 2 + LiveTranscript.paragraphGap + 1])
        XCTAssertEqual(transcript.lines.map(\.text), ["Empezamos.", "Segundo tema."])
    }

    func testAPauseExactlyAtTheLimitStillJoins() {
        let transcript = LiveTranscript()
            .applying(phrase("Uno.", 0, 2))
            .applying(phrase("Dos.", 2 + LiveTranscript.paragraphGap, 9))
        XCTAssertEqual(transcript.lines.count, 1)
    }

    func testAParagraphStopsGrowingAtTheLimit() {
        let long = String(repeating: "palabra ", count: 40).trimmingCharacters(in: .whitespaces)   // 319 characters
        let transcript = LiveTranscript()
            .applying(phrase(long, 0, 20))
            .applying(phrase(long, 21, 40))
        XCTAssertEqual(transcript.lines.count, 2)
        XCTAssertLessThanOrEqual(transcript.lines[0].text.count, LiveTranscript.paragraphLimit)
    }

    func testAMarkerBreaksTheParagraphAndKeepsItsPlace() {
        let transcript = LiveTranscript()
            .applying(phrase("Antes de la llamada.", 0, 3))
            .appendingMarker("Pausa", at: 4)
            .applying(phrase("Después de la llamada.", 5, 8))
        XCTAssertEqual(transcript.lines, [
            TranscriptLine(speaker: .room, start: 0, text: "Antes de la llamada."),
            TranscriptLine(speaker: .marker, start: 4, text: "Pausa"),
            TranscriptLine(speaker: .room, start: 5, text: "Después de la llamada."),
        ])
    }

    func testAMarkerDropsVolatileTextThatNeverSettled() {
        let transcript = LiveTranscript()
            .applying(phrase("a medias", 0, 1, final: false))
            .appendingMarker("Pausa", at: 2)
        XCTAssertEqual(transcript.volatile, "")
    }

    func testBlankPhrasesAreIgnored() {
        let transcript = LiveTranscript()
            .applying(phrase("   ", 0, 1))
            .applying(phrase("\n", 1, 2, final: false))
        XCTAssertTrue(transcript.lines.isEmpty)
        XCTAssertEqual(transcript.volatile, "")
    }

    func testAFinalPhraseWithoutTextStillClearsTheVolatileText() {
        let transcript = LiveTranscript()
            .applying(phrase("ruido", 0, 1, final: false))
            .applying(phrase(" ", 0, 1))
        XCTAssertEqual(transcript.volatile, "")
    }

    func testTextAroundThePhraseIsTrimmed() {
        let transcript = LiveTranscript().applying(phrase("  Hola.\n", 0, 1))
        XCTAssertEqual(transcript.lines.first?.text, "Hola.")
    }

    func testApplyingReturnsANewValue() {
        let empty = LiveTranscript()
        _ = empty.applying(phrase("Hola.", 0, 1))
        XCTAssertEqual(empty, LiveTranscript())
    }

    func testTheSpokenWordsCountEveryLineButNotTheMarkers() {
        let transcript = LiveTranscript()
            .applying(phrase("uno dos tres", 0, 2))
            .appendingMarker("Pausa por una llamada", at: 3)
            .applying(phrase("cuatro cinco", 10, 12))
        XCTAssertEqual(transcript.spokenWords, 5)
    }

    func testAJournalRebuiltFromThePhrasesGivesTheSameLines() {
        let phrases = [phrase("Uno.", 0, 1), phrase("Dos.", 2, 3), phrase("Tres.", 30, 31)]
        let live = phrases.reduce(LiveTranscript()) { $0.applying($1) }
        let rebuilt = LiveTranscript(lines: [], volatile: "").applying(phrases[0]).applying(phrases[1]).applying(phrases[2])
        XCTAssertEqual(live.lines, rebuilt.lines)
    }
}
