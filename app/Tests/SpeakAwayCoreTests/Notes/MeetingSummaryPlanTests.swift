import XCTest
@testable import SpeakAwayCore

/// What goes to the on-device model when a meeting stops, and whether it goes at all.
final class MeetingTranscriptTests: XCTestCase {
    private func room(_ start: TimeInterval, _ text: String) -> TranscriptLine { TranscriptLine(speaker: .room, start: start, text: text) }

    func testRoomParagraphsGoOneBelowTheOtherWithoutLabels() {
        XCTAssertEqual(MeetingTranscript.text(for: [room(0, "Uno."), room(30, "Dos.")]), "Uno.\nDos.")
    }

    func testMarkersAreNotPartOfWhatIsSummarized() {
        let lines = [room(0, "Antes."), TranscriptLine(speaker: .marker, start: 10, text: "Pausa"), room(20, "Después.")]
        XCTAssertEqual(MeetingTranscript.text(for: lines), "Antes.\nDespués.")
    }

    func testLinesAreOrderedByTime() {
        XCTAssertEqual(MeetingTranscript.text(for: [room(30, "Dos."), room(0, "Uno.")]), "Uno.\nDos.")
    }

    func testMeetingsWithTwoSidesKeepTheMacsLabels() {
        let lines = [TranscriptLine(speaker: .me, start: 0, text: "Hola."), TranscriptLine(speaker: .them, start: 5, text: "Buenas.")]
        XCTAssertEqual(MeetingTranscript.text(for: lines), "Yo: Hola.\nEllos: Buenas.")
    }

    func testBlankLinesAreLeftOut() {
        XCTAssertEqual(MeetingTranscript.text(for: [room(0, "  "), room(5, "Algo.")]), "Algo.")
        XCTAssertEqual(MeetingTranscript.text(for: []), "")
    }

    func testWordsCountWhatWasSaidAndNotTheMarkers() {
        let lines = [room(0, "uno dos tres"), TranscriptLine(speaker: .marker, start: 3, text: "Pausa por una llamada"), room(9, "cuatro  cinco\nseis")]
        XCTAssertEqual(MeetingTranscript.spokenWords(in: lines), 6)
    }

    func testAMeetingNeedsAFewSentencesToBeWorthSummarizing() {
        let few = [room(0, String(repeating: "palabra ", count: MeetingTranscript.minimumWords - 1))]
        let enough = [room(0, String(repeating: "palabra ", count: MeetingTranscript.minimumWords))]
        XCTAssertFalse(MeetingTranscript.hasEnoughToSummarize(few))
        XCTAssertTrue(MeetingTranscript.hasEnoughToSummarize(enough))
        XCTAssertFalse(MeetingTranscript.hasEnoughToSummarize([]))
    }
}

final class SummaryPlanTests: XCTestCase {
    private let enough = [TranscriptLine(speaker: .room, start: 0, text: String(repeating: "palabra ", count: 40))]
    private let little = [TranscriptLine(speaker: .room, start: 0, text: "Hola")]

    func testABrainThatIsOnAndAvailableSummarizesNow() {
        XCTAssertEqual(SummaryPlan.decide(lines: enough, brainOn: true, availability: .available), .summarizeNow)
    }

    func testNothingIsSummarizedWhenAlmostNothingWasSaid() {
        for availability: BrainAvailability in [.available, .modelNotReady, .unsupportedOS] {
            XCTAssertEqual(SummaryPlan.decide(lines: little, brainOn: true, availability: availability), .nothingToSummarize)
            XCTAssertEqual(SummaryPlan.decide(lines: [], brainOn: true, availability: availability), .nothingToSummarize)
        }
    }

    func testWithoutAppleIntelligenceTheTranscriptIsAllThereIs() {
        for availability: BrainAvailability in [.needsAppleIntelligence, .unsupportedOS, .deviceNotEligible] {
            XCTAssertEqual(SummaryPlan.decide(lines: enough, brainOn: true, availability: availability), .needsAppleIntelligence, "\(availability)")
            XCTAssertEqual(SummaryPlan.decide(lines: enough, brainOn: false, availability: availability), .needsAppleIntelligence, "\(availability)")
        }
    }

    func testABrainSwitchedOffInTheAppKeepsTheTranscriptOnly() {
        XCTAssertEqual(SummaryPlan.decide(lines: enough, brainOn: false, availability: .available), .brainOff)
        XCTAssertEqual(SummaryPlan.decide(lines: enough, brainOn: false, availability: .modelNotReady), .brainOff)
    }

    func testAModelStillPreparingIsTriedAgainLater() {
        XCTAssertEqual(SummaryPlan.decide(lines: enough, brainOn: true, availability: .modelNotReady), .leaveForLater)
    }

    func testOnlyTheOnePlanRunsTheModelOnStop() {
        XCTAssertTrue(SummaryPlan.summarizeNow.runsOnStop)
        for plan: SummaryPlan in [.nothingToSummarize, .brainOff, .leaveForLater, .needsAppleIntelligence] {
            XCTAssertFalse(plan.runsOnStop, "\(plan)")
        }
    }
}
