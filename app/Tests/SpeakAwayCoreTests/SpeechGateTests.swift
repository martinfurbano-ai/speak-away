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
        for i in 4_000..<12_000 { audio[i] = 0.05 * sin(Float(i) * 0.3) }
        XCTAssertEqual(SpeechGate.check(audio, sampleRate: rate), .speech)
    }

    /// A key click or the start chime makes one loud instant over room noise. Whisper turns that into
    /// invented text ("*pick*", "I think it's a good night"), so it must not count as speech.
    func testAClickOverRoomNoiseIsSilent() {
        var audio = (0..<rate * 3).map { i in 0.002 * sin(Float(i) * 1.7) }
        for i in 800..<1_000 { audio[i] += 0.05 }
        XCTAssertEqual(SpeechGate.check(audio, sampleRate: rate), .silent)
    }

    func testAShortChimeOverRoomNoiseIsSilent() {
        var audio = (0..<rate * 3).map { i in 0.002 * sin(Float(i) * 1.7) }
        for i in 0..<2_400 { audio[i] += 0.03 * sin(Float(i) * 0.35) }
        XCTAssertEqual(SpeechGate.check(audio, sampleRate: rate), .silent)
    }

    func testQuietButSustainedSpeechIsTranscribed() {
        let audio = (0..<rate * 3).map { i in 0.008 * sin(Float(i) * 0.3) }
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
