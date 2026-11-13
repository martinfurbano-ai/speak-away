import XCTest
@testable import SpeakAwayCore

/// What the recorder does when the user, a phone call or the microphone's route changes the moment.
final class MeetingFlowTests: XCTestCase {
    private func step(_ phase: MeetingPhase, _ event: MeetingEvent) -> MeetingStep {
        MeetingFlow.step(phase, event)
    }

    // MARK: Start and stop

    func testStartingBeginsCapture() {
        let next = step(.idle, .startRequested)
        XCTAssertEqual(next.phase, .recording)
        XCTAssertEqual(next.effects, [.beginCapture])
    }

    func testNothingHappensToAMeetingThatIsNotRunning() {
        for event in [MeetingEvent.pauseRequested, .resumeRequested, .interruptionBegan, .interruptionEnded(shouldResume: true),
                      .microphoneChanged, .stopRequested, .captureFailed] {
            XCTAssertEqual(step(.idle, event), MeetingStep(phase: .idle, effects: []), "\(event)")
        }
    }

    func testStoppingFinishesFromEveryRunningPhase() {
        for phase in [MeetingPhase.recording, .paused(.user), .paused(.interruption)] {
            let next = step(phase, .stopRequested)
            XCTAssertEqual(next.phase, .idle, "\(phase)")
            XCTAssertEqual(next.effects, [.finish], "\(phase)")
        }
    }

    func testStartingAgainWhileRunningChangesNothing() {
        for phase in [MeetingPhase.recording, .paused(.user), .paused(.interruption)] {
            XCTAssertEqual(step(phase, .startRequested), MeetingStep(phase: phase, effects: []))
        }
    }

    // MARK: Pause and resume by the user

    func testPausingStopsCaptureAndLeavesAMarker() {
        let next = step(.recording, .pauseRequested)
        XCTAssertEqual(next.phase, .paused(.user))
        XCTAssertEqual(next.effects, [.suspendCapture, .mark(.paused)])
    }

    func testResumingAUserPauseStartsCaptureAgain() {
        let next = step(.paused(.user), .resumeRequested)
        XCTAssertEqual(next.phase, .recording)
        XCTAssertEqual(next.effects, [.beginCapture, .mark(.resumed)])
    }

    func testResumingWhileRecordingChangesNothing() {
        XCTAssertEqual(step(.recording, .resumeRequested), MeetingStep(phase: .recording, effects: []))
    }

    func testPausingWhilePausedChangesNothing() {
        XCTAssertEqual(step(.paused(.user), .pauseRequested), MeetingStep(phase: .paused(.user), effects: []))
        XCTAssertEqual(step(.paused(.interruption), .pauseRequested), MeetingStep(phase: .paused(.interruption), effects: []))
    }

    // MARK: Interruptions (a phone call, Siri, an alarm)

    func testAnInterruptionPausesWithAMarker() {
        let next = step(.recording, .interruptionBegan)
        XCTAssertEqual(next.phase, .paused(.interruption))
        XCTAssertEqual(next.effects, [.suspendCapture, .mark(.interrupted)])
    }

    func testTheEndOfAnInterruptionResumesWhenTheSystemSaysSo() {
        let next = step(.paused(.interruption), .interruptionEnded(shouldResume: true))
        XCTAssertEqual(next.phase, .recording)
        XCTAssertEqual(next.effects, [.beginCapture, .mark(.resumed)])
    }

    func testTheEndOfAnInterruptionWaitsForTheUserWhenTheSystemDoesNotAllowResuming() {
        let next = step(.paused(.interruption), .interruptionEnded(shouldResume: false))
        XCTAssertEqual(next, MeetingStep(phase: .paused(.interruption), effects: []))
    }

    func testTheUserCanResumeAfterAnInterruption() {
        let next = step(.paused(.interruption), .resumeRequested)
        XCTAssertEqual(next.phase, .recording)
        XCTAssertEqual(next.effects, [.beginCapture, .mark(.resumed)])
    }

    func testACallDuringAUserPauseDoesNotResumeIt() {
        XCTAssertEqual(step(.paused(.user), .interruptionBegan), MeetingStep(phase: .paused(.user), effects: []))
        XCTAssertEqual(step(.paused(.user), .interruptionEnded(shouldResume: true)), MeetingStep(phase: .paused(.user), effects: []))
    }

    func testAnInterruptionThatBeginsTwiceIsOneInterruption() {
        XCTAssertEqual(step(.paused(.interruption), .interruptionBegan), MeetingStep(phase: .paused(.interruption), effects: []))
    }

    func testAnInterruptionEndWithoutABeginDoesNothingWhileRecording() {
        XCTAssertEqual(step(.recording, .interruptionEnded(shouldResume: true)), MeetingStep(phase: .recording, effects: []))
    }

    // MARK: Route changes (AirPods connect or disconnect)

    func testANewMicrophoneRestartsCaptureWithAMarker() {
        let next = step(.recording, .microphoneChanged)
        XCTAssertEqual(next.phase, .recording)
        XCTAssertEqual(next.effects, [.restartCapture, .mark(.microphoneChanged)])
    }

    func testANewMicrophoneWhilePausedChangesNothing() {
        XCTAssertEqual(step(.paused(.user), .microphoneChanged), MeetingStep(phase: .paused(.user), effects: []))
        XCTAssertEqual(step(.paused(.interruption), .microphoneChanged), MeetingStep(phase: .paused(.interruption), effects: []))
    }

    // MARK: Failures

    func testAMicrophoneThatCannotRestartPausesTheMeetingSoNothingIsLost() {
        let next = step(.recording, .captureFailed)
        XCTAssertEqual(next.phase, .paused(.interruption))
        XCTAssertEqual(next.effects, [.suspendCapture, .mark(.interrupted)])
    }

    func testAFailureWhilePausedChangesNothing() {
        XCTAssertEqual(step(.paused(.user), .captureFailed), MeetingStep(phase: .paused(.user), effects: []))
    }

    // MARK: Words for the markers

    func testEveryMarkerHasPlainEnglishAndSpanishText() {
        let markers: [MeetingMarker] = [.paused, .resumed, .interrupted, .microphoneChanged, .endedUnexpectedly]
        for marker in markers {
            XCTAssertFalse(marker.text(english: true).isEmpty)
            XCTAssertFalse(marker.text(english: false).isEmpty)
            XCTAssertNotEqual(marker.text(english: true), marker.text(english: false))
            XCTAssertFalse(marker.text(english: true).contains("\u{2014}"))
            XCTAssertFalse(marker.text(english: false).contains("\u{2014}"))
        }
    }
}

final class MeetingClockTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private func at(_ seconds: Double) -> Date { t0.addingTimeInterval(seconds) }

    func testElapsedGrowsWhileRecording() {
        let clock = MeetingClock(startedAt: t0)
        XCTAssertEqual(clock.elapsed(at: at(0)), 0)
        XCTAssertEqual(clock.elapsed(at: at(75)), 75, accuracy: 1e-9)
    }

    func testElapsedStopsWhilePaused() {
        let clock = MeetingClock(startedAt: t0).paused(at: at(60))
        XCTAssertTrue(clock.isPaused)
        XCTAssertEqual(clock.elapsed(at: at(60)), 60, accuracy: 1e-9)
        XCTAssertEqual(clock.elapsed(at: at(500)), 60, accuracy: 1e-9)
    }

    func testElapsedLeavesOutTheTimeSpentPaused() {
        let clock = MeetingClock(startedAt: t0).paused(at: at(60)).resumed(at: at(180))
        XCTAssertFalse(clock.isPaused)
        XCTAssertEqual(clock.elapsed(at: at(200)), 80, accuracy: 1e-9)
    }

    func testTwoPausesAddUp() {
        let clock = MeetingClock(startedAt: t0)
            .paused(at: at(10)).resumed(at: at(20))
            .paused(at: at(40)).resumed(at: at(100))
        XCTAssertEqual(clock.elapsed(at: at(130)), 10 + 20 + 30, accuracy: 1e-9)
    }

    func testTheOffsetOfALineCountsThePausesBecauseItIsTheTimeInTheMeeting() {
        let clock = MeetingClock(startedAt: t0).paused(at: at(60)).resumed(at: at(180))
        XCTAssertEqual(clock.offset(at: at(200)), 200, accuracy: 1e-9)
    }

    func testPausingTwiceKeepsTheFirstPause() {
        let clock = MeetingClock(startedAt: t0).paused(at: at(10)).paused(at: at(50)).resumed(at: at(60))
        XCTAssertEqual(clock.elapsed(at: at(60)), 10, accuracy: 1e-9)
    }

    func testResumingWithoutAPauseChangesNothing() {
        let clock = MeetingClock(startedAt: t0)
        XCTAssertEqual(clock.resumed(at: at(30)), clock)
    }

    func testTheChangesReturnNewValues() {
        let clock = MeetingClock(startedAt: t0)
        _ = clock.paused(at: at(5))
        XCTAssertFalse(clock.isPaused)
    }

    func testAClockSetBackNeverGoesNegative() {
        let clock = MeetingClock(startedAt: t0)
        XCTAssertEqual(clock.elapsed(at: at(-30)), 0)
        XCTAssertEqual(clock.offset(at: at(-30)), 0)
    }
}

final class ElapsedFormatTests: XCTestCase {
    func testUnderAMinute() {
        XCTAssertEqual(ElapsedFormat.string(0), "0:00")
        XCTAssertEqual(ElapsedFormat.string(7), "0:07")
        XCTAssertEqual(ElapsedFormat.string(59.9), "0:59")
    }

    func testMinutes() {
        XCTAssertEqual(ElapsedFormat.string(60), "1:00")
        XCTAssertEqual(ElapsedFormat.string(754), "12:34")
        XCTAssertEqual(ElapsedFormat.string(3599), "59:59")
    }

    func testHours() {
        XCTAssertEqual(ElapsedFormat.string(3600), "1:00:00")
        XCTAssertEqual(ElapsedFormat.string(3723), "1:02:03")
        XCTAssertEqual(ElapsedFormat.string(36_000 + 59 * 60 + 59), "10:59:59")
    }

    func testBadValuesReadAsZero() {
        XCTAssertEqual(ElapsedFormat.string(-5), "0:00")
        XCTAssertEqual(ElapsedFormat.string(.nan), "0:00")
        XCTAssertEqual(ElapsedFormat.string(.infinity), "0:00")
    }
}
