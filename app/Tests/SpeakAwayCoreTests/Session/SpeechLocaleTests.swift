import XCTest
@testable import SpeakAwayCore

final class SpeechLocaleTests: XCTestCase {
    private let supported = ["en-US", "en-GB", "es-ES", "es-MX", "es-US", "fr-FR", "pt-BR", "zh-CN"]

    private func resolve(_ setting: String, _ preferred: [String]) -> String {
        SpeechLocale.resolve(setting: setting, preferred: preferred, supported: supported)
    }

    func testAutoUsesTheFirstSystemLanguageThatIsSupported() {
        XCTAssertEqual(resolve("auto", ["en-GB", "es-ES"]), "en-GB")
        XCTAssertEqual(resolve("auto", ["ja-JP", "fr-FR", "en-US"]), "fr-FR")
    }

    func testAutoFallsBackToUSEnglishWhenNothingIsSupported() {
        XCTAssertEqual(resolve("auto", ["ja-JP", "ko-KR"]), "en-US")
        XCTAssertEqual(resolve("auto", []), "en-US")
    }

    func testARegionThatIsNotSupportedMapsToTheSameLanguage() {
        // Spanish from Panama: Latin American Spanish is the closest.
        XCTAssertEqual(resolve("auto", ["es-PA"]), "es-MX")
        XCTAssertEqual(resolve("auto", ["en-AU"]), "en-US")
        XCTAssertEqual(resolve("auto", ["pt-PT"]), "pt-BR")
    }

    func testAnExactRegionWinsOverTheLanguageDefault() {
        XCTAssertEqual(resolve("auto", ["es-ES"]), "es-ES")
        XCTAssertEqual(resolve("auto", ["es-US"]), "es-US")
    }

    func testALanguageOnlySettingPicksTheDefaultRegion() {
        XCTAssertEqual(resolve("en", ["es-ES"]), "en-US")
        XCTAssertEqual(resolve("es", ["en-US"]), "es-MX")
    }

    func testAnExplicitSettingBeatsTheSystemLanguage() {
        XCTAssertEqual(resolve("es-ES", ["en-US"]), "es-ES")
    }

    func testAnUnsupportedSettingFallsBackToTheSystemLanguageThenEnglish() {
        XCTAssertEqual(resolve("xx", ["es-MX"]), "es-MX")
        XCTAssertEqual(resolve("xx", []), "en-US")
    }

    func testUnderscoresAndCaseAreAccepted() {
        XCTAssertEqual(resolve("auto", ["es_MX"]), "es-MX")
        XCTAssertEqual(resolve("EN-us", []), "en-US")
    }

    func testLanguageWithoutDefaultRegionUsesTheFirstSupportedOne() {
        let list = ["de-AT", "de-DE"]
        XCTAssertEqual(SpeechLocale.resolve(setting: "de", preferred: [], supported: list), "de-AT")
    }

    func testLanguageCode() {
        XCTAssertEqual(SpeechLocale.languageCode("es-MX"), "es")
        XCTAssertEqual(SpeechLocale.languageCode("en_US"), "en")
        XCTAssertEqual(SpeechLocale.languageCode("pt"), "pt")
    }
}
