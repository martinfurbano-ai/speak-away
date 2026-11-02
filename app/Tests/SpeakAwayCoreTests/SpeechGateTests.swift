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
}
