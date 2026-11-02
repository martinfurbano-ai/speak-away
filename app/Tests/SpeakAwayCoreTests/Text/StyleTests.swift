import XCTest
@testable import SpeakAwayCore

final class StyleTests: XCTestCase {
    // MARK: formal

    func testFormalAddsFinalPunctuation() {
        XCTAssertEqual(Style.apply("Hello there", style: .formal), "Hello there.")
        XCTAssertEqual(Style.apply("Hola, ¿cómo estás?", style: .formal), "Hola, ¿cómo estás?")
        XCTAssertEqual(Style.apply("Great!", style: .formal), "Great!")
        XCTAssertEqual(Style.apply("Hello there.", style: .formal), "Hello there.")
    }

    func testFormalTurnsDanglingCommaIntoPeriod() {
        XCTAssertEqual(Style.apply("Hello there,", style: .formal), "Hello there.")
    }

    func testFormalLeavesEmojiAndClosingMarksAlone() {
        XCTAssertEqual(Style.apply("Gracias 🙏", style: .formal), "Gracias 🙏")
        XCTAssertEqual(Style.apply("Dijo \"hola\"", style: .formal), "Dijo \"hola\"")
    }

    func testFormalKeepsOuterWhitespace() {
        XCTAssertEqual(Style.apply("Hello there ", style: .formal), "Hello there. ")
    }

    // MARK: casual

    func testCasualDropsFinalPeriodOfShortSingleSentence() {
        XCTAssertEqual(Style.apply("Sounds good.", style: .casual), "Sounds good")
        XCTAssertEqual(Style.apply("Nos vemos mañana.", style: .casual), "Nos vemos mañana")
        XCTAssertEqual(Style.apply("Sounds good. ", style: .casual), "Sounds good ")
    }

    func testCasualKeepsQuestionAndExclamation() {
        XCTAssertEqual(Style.apply("Are you coming?", style: .casual), "Are you coming?")
        XCTAssertEqual(Style.apply("¡Qué bueno!", style: .casual), "¡Qué bueno!")
    }

    func testCasualKeepsPeriodsOfSeveralSentencesOrLongText() {
        XCTAssertEqual(Style.apply("Hello. How are you.", style: .casual), "Hello. How are you.")
        let long = "I wanted to tell you that the meeting moved to next week because the client is travelling."
        XCTAssertEqual(Style.apply(long, style: .casual), long)
    }

    func testCasualKeepsEllipsisAndDecimals() {
        XCTAssertEqual(Style.apply("Well...", style: .casual), "Well...")
        XCTAssertEqual(Style.apply("It costs 3.5.", style: .casual), "It costs 3.5")
    }

    func testCasualKeepsCapitalLetters() {
        XCTAssertEqual(Style.apply("Hello there.", style: .casual), "Hello there")
    }

    // MARK: very casual

    func testVeryCasualLowercasesFirstLetterAndDropsPeriod() {
        XCTAssertEqual(Style.apply("Sounds good.", style: .veryCasual), "sounds good")
        XCTAssertEqual(Style.apply("Nos vemos mañana.", style: .veryCasual), "nos vemos mañana")
        XCTAssertEqual(Style.apply("¿Vienes?", style: .veryCasual), "¿vienes?")
    }

    func testVeryCasualKeepsIAndAcronymsAndBrands() {
        XCTAssertEqual(Style.apply("I think so.", style: .veryCasual), "I think so")
        XCTAssertEqual(Style.apply("I'm in.", style: .veryCasual), "I'm in")
        XCTAssertEqual(Style.apply("NASA called.", style: .veryCasual), "NASA called")
        XCTAssertEqual(Style.apply("iPhone is ready.", style: .veryCasual), "iPhone is ready")
    }

    func testVeryCasualDropsFinalPeriodAlsoInSeveralSentences() {
        XCTAssertEqual(Style.apply("Hello. How are you.", style: .veryCasual), "hello. How are you")
    }

    func testEmptyTextStaysEmpty() {
        for style in WritingStyle.allCases {
            XCTAssertEqual(Style.apply("", style: style), "")
            XCTAssertEqual(Style.apply("  ", style: style), "  ")
        }
    }

    // MARK: categories

    func testBundleIDsMapToCategories() {
        XCTAssertEqual(AppCategory(bundleID: "net.whatsapp.WhatsApp"), .messages)
        XCTAssertEqual(AppCategory(bundleID: "com.apple.MobileSMS"), .messages)
        XCTAssertEqual(AppCategory(bundleID: "com.tinyspeck.slackmacgap"), .messages)
        XCTAssertEqual(AppCategory(bundleID: "ru.keepcoder.Telegram"), .messages)
        XCTAssertEqual(AppCategory(bundleID: "com.hnc.Discord"), .messages)
        XCTAssertEqual(AppCategory(bundleID: "com.apple.mail"), .email)
        XCTAssertEqual(AppCategory(bundleID: "com.microsoft.Outlook"), .email)
        XCTAssertEqual(AppCategory(bundleID: "com.readdle.SparkDesktop"), .email)
        XCTAssertEqual(AppCategory(bundleID: "com.readdle.SparkDesktop.appstore"), .email)
        XCTAssertEqual(AppCategory(bundleID: "com.apple.Notes"), .work)
        XCTAssertEqual(AppCategory(bundleID: "com.apple.iWork.Pages"), .work)
        XCTAssertEqual(AppCategory(bundleID: "com.microsoft.Word"), .work)
        XCTAssertEqual(AppCategory(bundleID: "com.google.Chrome"), .other)
        XCTAssertEqual(AppCategory(bundleID: "com.apple.Safari"), .other)
    }

    func testBundleIDMatchIsCaseInsensitiveAndUnknownIsOther() {
        XCTAssertEqual(AppCategory(bundleID: "COM.APPLE.MAIL"), .email)
        XCTAssertEqual(AppCategory(bundleID: "com.example.unknown"), .other)
        XCTAssertEqual(AppCategory(bundleID: nil), .other)
        XCTAssertEqual(AppCategory(bundleID: ""), .other)
    }

    func testDefaultStylesPerCategory() {
        let s = StyleSettings()
        XCTAssertEqual(s.style(for: .messages), .casual)
        XCTAssertEqual(s.style(for: .email), .formal)
        XCTAssertEqual(s.style(for: .work), .formal)
        XCTAssertEqual(s.style(for: .other), .formal)
        XCTAssertEqual(s.style(forBundleID: "net.whatsapp.WhatsApp"), .casual)
        XCTAssertEqual(s.style(forBundleID: nil), .formal)
    }

    func testSettingAStyleReturnsANewValue() {
        let original = StyleSettings()
        let changed = original.setting(.veryCasual, for: .messages)
        XCTAssertEqual(changed.style(for: .messages), .veryCasual)
        XCTAssertEqual(original.style(for: .messages), .casual)
        XCTAssertEqual(changed.style(for: .email), .formal)
    }

    func testMissingCategoryFallsBackToDefault() {
        let s = StyleSettings(byCategory: [.email: .casual])
        XCTAssertEqual(s.style(for: .email), .casual)
        XCTAssertEqual(s.style(for: .messages), .casual)
        XCTAssertEqual(s.style(for: .work), .formal)
    }

    func testStyleSettingsCodableRoundTripUsesReadableKeys() throws {
        let s = StyleSettings().setting(.veryCasual, for: .messages)
        let data = try JSONEncoder().encode(s)
        XCTAssertEqual(try JSONDecoder().decode(StyleSettings.self, from: data), s)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("\"messages\":\"veryCasual\""), json)
    }
}
