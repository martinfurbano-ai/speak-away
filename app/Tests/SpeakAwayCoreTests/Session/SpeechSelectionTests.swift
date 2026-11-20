import XCTest
@testable import SpeakAwayCore

final class SpeechSelectionTests: XCTestCase {
    private func candidate(_ locale: String, _ text: String, _ confidence: Double?) -> SpeechCandidate {
        SpeechCandidate(locale: locale, text: text, confidence: confidence)
    }

    func testClearSpanishWinsOnAnEnglishPhone() {
        let spanish = candidate("es-MX", "Nos vemos mañana a las tres.", 0.94)
        let english = candidate("en-US", "Nose vemos manana last race.", 0.32)
        let inputs = [english, spanish]
        XCTAssertEqual(SpeechSelection.choose(inputs, preferredLocale: "en-US"), spanish)
        XCTAssertEqual(inputs, [english, spanish])
    }

    func testClearEnglishWinsOnASpanishPhone() {
        let english = candidate("en-US", "Please send the notes tomorrow.", 0.96)
        XCTAssertEqual(SpeechSelection.choose([candidate("es-MX", "Plis sen de nouts.", 0.4), english],
                                              preferredLocale: "es-MX"), english)
    }

    func testEmptyNoiseAndPunctuationCannotWin() {
        let spanish = candidate("es-MX", "Hola", 0.2)
        for noise in ["", "   ", "[BLANK_AUDIO]", "(noise)", "...!"] {
            XCTAssertEqual(SpeechSelection.choose([candidate("en-US", noise, 1), spanish],
                                                  preferredLocale: "en-US"), spanish)
        }
        XCTAssertNil(SpeechSelection.choose([candidate("en-US", "", 1)], preferredLocale: "en-US"))
    }

    func testTieUsesPreferredLanguageRegardlessOfInputOrder() {
        let english = candidate("en-US", "OK", 0.8)
        let spanish = candidate("es-MX", "OK", 0.8)
        XCTAssertEqual(SpeechSelection.choose([spanish, english], preferredLocale: "en-GB"), english)
        XCTAssertEqual(SpeechSelection.choose([english, spanish], preferredLocale: "es-ES"), spanish)
        XCTAssertEqual(SpeechSelection.choose([spanish, english], preferredLocale: "fr-FR"),
                       SpeechSelection.choose([english, spanish], preferredLocale: "fr-FR"))
    }

    func testShortSpanishAndMissingConfidence() {
        let spanish = candidate("es-MX", "Sí", 0.91)
        XCTAssertEqual(SpeechSelection.choose([candidate("en-US", "See", 0.62), spanish],
                                              preferredLocale: "en-US"), spanish)
        let unknown = candidate("es-MX", "Hola", nil)
        XCTAssertEqual(SpeechSelection.choose([candidate("en-US", "", 0.9), unknown],
                                              preferredLocale: "en-US"), unknown)
    }

    func testInvalidConfidenceDoesNotOutrankRealEvidence() {
        let english = candidate("en-US", "Hello", 0.4)
        for invalid in [Double.nan, Double.infinity, -1, 2] {
            XCTAssertEqual(SpeechSelection.choose([candidate("es-MX", "Alo", invalid), english],
                                                  preferredLocale: "es-MX"), english)
        }
    }

    func testBothMissingScoresUseStableTieRule() {
        let english = candidate("en-US", "OK", nil)
        XCTAssertEqual(SpeechSelection.choose([candidate("es-MX", "OK", nil), english],
                                              preferredLocale: "en-US"), english)
    }
}
