import XCTest
@testable import SpeakAwayCore

final class CaptureStatsTests: XCTestCase {
    func testStartsEmptyAndTooShort() {
        let stats = CaptureStats()
        XCTAssertEqual(stats.seconds, 0)
        XCTAssertEqual(stats.peak, 0)
        XCTAssertEqual(stats.verdict, .tooShort)
    }

    func testAddingKeepsTheTotalDurationAndTheHighestPeak() {
        let stats = CaptureStats()
            .adding(frames: 24_000, sampleRate: 48_000, peak: 0.2)
            .adding(frames: 24_000, sampleRate: 48_000, peak: 0.5)
            .adding(frames: 24_000, sampleRate: 48_000, peak: 0.1)
        XCTAssertEqual(stats.seconds, 1.5, accuracy: 1e-9)
        XCTAssertEqual(stats.peak, 0.5)
        XCTAssertEqual(stats.verdict, .speech)
    }

    func testAddingReturnsANewValue() {
        let empty = CaptureStats()
        _ = empty.adding(frames: 48_000, sampleRate: 48_000, peak: 1)
        XCTAssertEqual(empty, CaptureStats())
    }

    func testDurationStaysTrueWhenTheInputRateChanges() {
        // A route change (built-in mic to Bluetooth) changes the sample rate mid-recording.
        let stats = CaptureStats()
            .adding(frames: 48_000, sampleRate: 48_000, peak: 0.3)
            .adding(frames: 8_000, sampleRate: 16_000, peak: 0.3)
        XCTAssertEqual(stats.seconds, 1.5, accuracy: 1e-9)
    }

    func testSilenceIsSilent() {
        let stats = CaptureStats().adding(frames: 96_000, sampleRate: 48_000, peak: 0.004)
        XCTAssertEqual(stats.verdict, .silent)
    }

    func testBadInputIsIgnored() {
        let stats = CaptureStats()
            .adding(frames: 0, sampleRate: 48_000, peak: 0.9)
            .adding(frames: 100, sampleRate: 0, peak: 0.9)
            .adding(frames: -5, sampleRate: 48_000, peak: 0.9)
        XCTAssertEqual(stats, CaptureStats())
    }

    func testANonFinitePeakIsIgnored() {
        let stats = CaptureStats().adding(frames: 48_000, sampleRate: 48_000, peak: .nan)
        XCTAssertEqual(stats.peak, 0)
        XCTAssertEqual(stats.seconds, 1, accuracy: 1e-9)
    }
}

final class SessionTickTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private func at(_ seconds: Double) -> Date { t0.addingTimeInterval(seconds) }

    func testAReadySessionIsQuietBetweenHeartbeats() {
        XCTAssertEqual(SessionTick.decide(state: .ready(until: at(900)), publishedAt: t0, sessionEnd: at(900), now: at(3.9)), .none)
    }

    func testAReadySessionRepublishesEveryHeartbeat() {
        XCTAssertEqual(SessionTick.decide(state: .ready(until: at(900)), publishedAt: t0, sessionEnd: at(900), now: at(4)), .heartbeat)
    }

    func testAReadySessionExpires() {
        XCTAssertEqual(SessionTick.decide(state: .ready(until: at(900)), publishedAt: at(898), sessionEnd: at(900), now: at(900)), .expire)
    }

    func testAnUntilStoppedSessionNeverExpires() {
        XCTAssertEqual(SessionTick.decide(state: .ready(until: nil), publishedAt: t0, sessionEnd: nil, now: at(86_400)), .heartbeat)
    }

    func testRecordingAndTranscribingAreKeptFresh() {
        XCTAssertEqual(SessionTick.decide(state: .recording(level: 0.4), publishedAt: t0, sessionEnd: at(900), now: at(5)), .heartbeat)
        XCTAssertEqual(SessionTick.decide(state: .transcribing, publishedAt: t0, sessionEnd: at(900), now: at(5)), .heartbeat)
    }

    func testAnExpiredSessionWaitsForTheDictationInProgress() {
        XCTAssertEqual(SessionTick.decide(state: .recording(level: 0.4), publishedAt: at(999), sessionEnd: at(900), now: at(1000)), .none)
        XCTAssertEqual(SessionTick.decide(state: .transcribing, publishedAt: at(999), sessionEnd: at(900), now: at(1000)), .none)
    }

    func testAFinishedResultStaysPublishedForTheHoldAndThenSettles() {
        let done = SessionState.done(id: UUID(), text: "hello ")
        XCTAssertEqual(SessionTick.decide(state: done, publishedAt: t0, sessionEnd: at(900), now: at(SessionTick.resultHold - 0.1)), .none)
        XCTAssertEqual(SessionTick.decide(state: done, publishedAt: t0, sessionEnd: at(900), now: at(SessionTick.resultHold)), .settle)
    }

    func testAFailureSettlesLikeAResult() {
        let failed = SessionState.failed(reason: "x")
        XCTAssertEqual(SessionTick.decide(state: failed, publishedAt: t0, sessionEnd: at(900), now: at(SessionTick.resultHold)), .settle)
    }

    func testASessionThatExpiredDuringTheHoldEndsRightAfterIt() {
        let done = SessionState.done(id: UUID(), text: "hello ")
        XCTAssertEqual(SessionTick.decide(state: done, publishedAt: at(899), sessionEnd: at(900), now: at(901)), .none)
        XCTAssertEqual(SessionTick.decide(state: done, publishedAt: at(899), sessionEnd: at(900), now: at(899 + SessionTick.resultHold)), .expire)
    }

    func testIdleHasNothingToDo() {
        XCTAssertEqual(SessionTick.decide(state: .idle, publishedAt: t0, sessionEnd: nil, now: at(100)), .none)
    }

    func testTheHoldIsShorterThanTheStaleLimit() {
        // The keyboard treats a state older than staleAfter as no session, so the app must settle first.
        XCTAssertLessThan(SessionTick.resultHold, SessionLiveness.staleAfter)
        XCTAssertLessThan(SessionLiveness.heartbeatInterval, SessionLiveness.staleAfter)
    }
}

final class SessionDispatchTests: XCTestCase {
    private let ready = SessionState.ready(until: nil)
    private let done = SessionState.done(id: UUID(), text: "x ")

    func testStartBeginsADictationWhenReady() {
        XCTAssertEqual(SessionDispatch.intent(for: .start, in: ready), .beginDictation)
        XCTAssertEqual(SessionDispatch.intent(for: .start, in: done), .beginDictation)
        XCTAssertEqual(SessionDispatch.intent(for: .start, in: .failed(reason: "x")), .beginDictation)
    }

    func testStartWhileBusyOrWithoutASessionIsIgnored() {
        XCTAssertEqual(SessionDispatch.intent(for: .start, in: .recording(level: 0.2)), .ignore)
        XCTAssertEqual(SessionDispatch.intent(for: .start, in: .transcribing), .ignore)
        XCTAssertEqual(SessionDispatch.intent(for: .start, in: .idle), .ignore)
    }

    func testStartCommandCarriesTheTargetText() {
        XCTAssertEqual(SessionDispatch.intent(for: .startCommand(on: "make it formal"), in: ready), .beginCommand(on: "make it formal"))
        XCTAssertEqual(SessionDispatch.intent(for: .startCommand(on: "x"), in: .recording(level: 0)), .ignore)
    }

    func testStopAndCancelOnlyMatterWhileRecording() {
        XCTAssertEqual(SessionDispatch.intent(for: .stop, in: .recording(level: 0.3)), .finish)
        XCTAssertEqual(SessionDispatch.intent(for: .cancel, in: .recording(level: 0.3)), .cancel)
        for state in [ready, done, SessionState.transcribing, .idle, .failed(reason: "x")] {
            XCTAssertEqual(SessionDispatch.intent(for: .stop, in: state), .ignore)
            XCTAssertEqual(SessionDispatch.intent(for: .cancel, in: state), .ignore)
        }
    }

    func testAWrittenCommandRunsRightAwayWhenTheSessionIsFree() {
        XCTAssertEqual(SessionDispatch.intent(for: .command(instruction: "shorter", on: "a long text"), in: ready),
                       .runCommand(instruction: "shorter", on: "a long text"))
        XCTAssertEqual(SessionDispatch.intent(for: .command(instruction: "shorter", on: "a long text"), in: .transcribing), .ignore)
        XCTAssertEqual(SessionDispatch.intent(for: .command(instruction: "shorter", on: "a long text"), in: .idle), .ignore)
    }
}

final class PolishedTextTests: XCTestCase {
    private func prepared(_ text: String) -> PreparedDictation {
        PreparedDictation(raw: text, text: text, style: .casual)
    }

    func testThePolishedTextKeepsTheTrailingSpaceTheKeyboardNeeds() {
        XCTAssertEqual(DictationFlow.polished("Let's meet tomorrow.", replacing: prepared("lets meet tomorrow ")), "Let's meet tomorrow. ")
    }

    func testLeadingWhitespaceIsKeptToo() {
        XCTAssertEqual(DictationFlow.polished("Hello.", replacing: prepared(" hello ")), " Hello. ")
    }

    func testAnEmptyPolishResultFallsBackToThePreparedText() {
        XCTAssertEqual(DictationFlow.polished("  \n", replacing: prepared("hello there ")), "hello there ")
    }

    func testTextWithoutWhitespaceStaysWithout() {
        XCTAssertEqual(DictationFlow.polished("Hi.", replacing: prepared("hi")), "Hi.")
    }
}
