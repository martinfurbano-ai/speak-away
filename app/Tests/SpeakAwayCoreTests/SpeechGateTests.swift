import XCTest
@testable import SpeakAwayCore

final class SpeechGateTests: XCTestCase {
    let rate = 16_000

    func testTooShortIsSkipped() {
        let audio = [Float](repeating: 0.3, count: rate / 5)
        XCTAssertEqual(SpeechGate.check(audio, sampleRate: rate), .tooShort)
    }

    func testSilenceIsSkippedSoWhisperDoesNotInventText() {
        let audio = [Float](repeating: 0.004, count: rate)
        XCTAssertEqual(SpeechGate.check(audio, sampleRate: rate), .silent)
    }

    func testVoiceIsTranscribed() {
        var audio = [Float](repeating: 0.001, count: rate)
        audio[8_000] = 0.2
        XCTAssertEqual(SpeechGate.check(audio, sampleRate: rate), .speech)
    }

    func testCleanTrimsAndAddsTrailingSpace() {
        XCTAssertEqual(SpeechGate.clean("  Hola, Carla.  "), "Hola, Carla. ")
    }

    func testCleanDropsWhisperBlankMarkers() {
        XCTAssertEqual(SpeechGate.clean(" [BLANK_AUDIO] "), "")
        XCTAssertEqual(SpeechGate.clean("(música)"), "")
    }

    // MARK: Measured while recording (the audio itself is never kept)

    func testDurationAndPeakGiveTheSameVerdictAsTheSamples() {
        XCTAssertEqual(SpeechGate.check(duration: 0.2, peak: 0.3), .tooShort)
        XCTAssertEqual(SpeechGate.check(duration: 1, peak: 0.004), .silent)
        XCTAssertEqual(SpeechGate.check(duration: 1, peak: 0.2), .speech)
    }

    func testTheShortLimitIsExactlyTheMinimumSeconds() {
        XCTAssertEqual(SpeechGate.check(duration: SpeechGate.minSeconds, peak: 0.2), .speech)
        XCTAssertEqual(SpeechGate.check(duration: SpeechGate.minSeconds - 0.01, peak: 0.2), .tooShort)
    }

    func testThePeakLimitIsExactlyTheSilenceLevel() {
        XCTAssertEqual(SpeechGate.check(duration: 1, peak: SpeechGate.silencePeak), .speech)
        XCTAssertEqual(SpeechGate.check(duration: 1, peak: SpeechGate.silencePeak - 0.001), .silent)
    }
}
