import XCTest
@testable import SpeakAwayCore

final class DictationLanguageTests: XCTestCase {
    func testSpanishWinsWhenAnotherLanguageLeadsOverall() {
        XCTAssertEqual(DictationLanguage.pick(from: ["nn": -0.5, "es": -1.2, "en": -2.0]), "es")
    }

    func testEnglishWinsWhenMoreLikelyThanSpanish() {
        XCTAssertEqual(DictationLanguage.pick(from: ["en": -0.3, "es": -1.5, "fr": -2.0]), "en")
    }

    func testNilWhenNeitherCandidateIsKnown() {
        XCTAssertNil(DictationLanguage.pick(from: ["fr": -0.3]))
    }
}
