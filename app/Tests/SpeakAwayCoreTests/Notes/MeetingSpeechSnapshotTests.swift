import XCTest
@testable import SpeakAwayCore

final class MeetingSpeechSnapshotTests: XCTestCase {
    private func phrase(_ text: String, _ start: Double, _ end: Double, final: Bool = true) -> RecognizedPhrase {
        RecognizedPhrase(text: text, start: start, end: end, isFinal: final)
    }

    func testIndependentSegmentationNeverMixesCandidateLanguages() {
        let spanish = MeetingSpeechSnapshot(locale: "es-MX")
            .applying(phrase("Buenos días.", 0, 2), confidence: 0.95)
            .applying(phrase("Empezamos la reunión.", 2, 5), confidence: 0.9)
        let english = MeetingSpeechSnapshot(locale: "en-US")
            .applying(phrase("When was the reunion?", 0, 5), confidence: 0.2)
        let chosen = SpeechSelection.choose([english.candidate, spanish.candidate], preferredLocale: "en-US")
        XCTAssertEqual(chosen?.locale, spanish.locale)
        XCTAssertEqual(spanish.transcript().lines.map(\.text), ["Buenos días. Empezamos la reunión."])
        XCTAssertEqual(english.transcript().lines.map(\.text), ["When was the reunion?"])
    }

    func testMarkersKeepTheirTimelineWhenTheSelectedSnapshotChanges() {
        let snapshot = MeetingSpeechSnapshot(locale: "es-MX")
            .applying(phrase("Antes.", 0, 2), confidence: 0.9)
            .applying(phrase("Después.", 4, 6), confidence: 0.9)
        let markers = [TranscriptLine(speaker: .marker, start: 3, text: "Pausa")]
        XCTAssertEqual(snapshot.transcript(markers: markers).lines.map(\.text), ["Antes.", "Pausa", "Después."])
    }

    func testPauseMarkerPrecedesSpeechThatResumesAtTheSameAudioTime() {
        let snapshot = MeetingSpeechSnapshot(locale: "es-MX")
            .applying(phrase("Antes.", 0, 2), confidence: 0.9)
            .applying(phrase("Después.", 2, 4), confidence: 0.9)
        let markers = [TranscriptLine(speaker: .marker, start: 2, text: "Pausa")]
        XCTAssertEqual(snapshot.transcript(markers: markers).lines.map(\.text), ["Antes.", "Pausa", "Después."])
    }

    func testLatestVolatileReplacesEarlierGuessAndFinalSettlesIt() {
        let initial = MeetingSpeechSnapshot(locale: "es-MX")
        let pending = initial.applying(phrase("Buenos", 0, 1, final: false), confidence: 0.5)
            .applying(phrase("Buenos días", 0, 2, final: false), confidence: 0.8)
        XCTAssertEqual(pending.transcript().volatile, "Buenos días")
        let settled = pending.applying(phrase("Buenos días.", 0, 2), confidence: 0.95)
        XCTAssertEqual(settled.transcript().volatile, "")
        XCTAssertEqual(settled.transcript().lines.map(\.text), ["Buenos días."])
        XCTAssertTrue(initial.phrases.isEmpty)
        XCTAssertNil(initial.pending)
    }

    func testFinalSnapshotJournalRecoversExactlyTheSelectedLines() {
        let snapshot = MeetingSpeechSnapshot(locale: "es-MX")
            .applying(phrase("Primer punto.", 0, 2), confidence: 0.9)
            .applying(phrase("Segundo punto.", 4, 6), confidence: 0.9)
        let markers = [TranscriptLine(speaker: .marker, start: 3, text: "Pausa")]
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let header = MeetingJournal.Header(id: UUID(), startedAt: now, app: "iPhone", title: "Reunión")
        let text = ([MeetingJournal.line(begin: header)] + snapshot.journalEntries(markers: markers).map(MeetingJournal.line(for:)))
            .joined(separator: "\n")
        let recovered = MeetingJournal.recover(from: text, lastActivity: now.addingTimeInterval(6), endNote: "")
        XCTAssertEqual(recovered?.lines, snapshot.transcript(markers: markers).lines)
    }

    func testUnsettledLastWordsCanBeFinalizedWithoutChangingOriginal() {
        let pending = MeetingSpeechSnapshot(locale: "es-MX")
            .applying(phrase("Últimas palabras", 4, 5, final: false), confidence: 0.8)
        let settled = pending.settled(endingAt: 6)
        XCTAssertEqual(settled.transcript().lines.map(\.text), ["Últimas palabras"])
        XCTAssertEqual(settled.transcript().volatile, "")
        XCTAssertEqual(pending.transcript().volatile, "Últimas palabras")
    }

    func testConfidenceWeightsRecognizedTextAndIgnoresMissingConfidence() {
        let snapshot = MeetingSpeechSnapshot(locale: "es-MX")
            .applying(phrase("hola", 0, 1), confidence: 0.9)
            .applying(phrase("amigos", 2, 3), confidence: 0.5)
        XCTAssertEqual(snapshot.candidate.confidence ?? 0, 0.66, accuracy: 0.001)
        XCTAssertNil(MeetingSpeechSnapshot(locale: "en-US").applying(phrase("hello", 0, 1), confidence: nil).candidate.confidence)
    }
}
