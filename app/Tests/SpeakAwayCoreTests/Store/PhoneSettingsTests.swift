import XCTest
@testable import SpeakAwayCore

final class PhoneSettingsTests: XCTestCase {
    func testDefaults() {
        let s = PhoneSettings()
        XCTAssertEqual(s.language, "auto")
        XCTAssertTrue(s.autoEdit)
        XCTAssertFalse(s.polish, "polish is off by default, like the Mac")
        XCTAssertEqual(s.sessionLength, .fifteenMinutes)
        XCTAssertTrue(s.sounds)
        XCTAssertTrue(s.haptics)
        XCTAssertTrue(s.historyEnabled)
        XCTAssertEqual(s.microphone, "", "empty means the one the system picks")
    }

    func testTheChosenMicrophoneIsKeptAndAnOldFileStillLoads() throws {
        let chosen = PhoneSettings().changing { $0.microphone = "BuiltInMicrophoneBottom" }
        let data = try JSONEncoder().encode(chosen)
        XCTAssertEqual(try JSONDecoder().decode(PhoneSettings.self, from: data).microphone, "BuiltInMicrophoneBottom")
        let old = try JSONDecoder().decode(PhoneSettings.self, from: Data(#"{"language":"es","sounds":false}"#.utf8))
        XCTAssertEqual(old.microphone, "")
        XCTAssertFalse(old.sounds)
    }

    func testChangingReturnsANewValue() {
        let original = PhoneSettings()
        let changed = original.changing { $0.polish = true; $0.language = "es" }
        XCTAssertFalse(original.polish)
        XCTAssertEqual(original.language, "auto")
        XCTAssertTrue(changed.polish)
        XCTAssertEqual(changed.language, "es")
    }

    func testRoundTrip() throws {
        let original = PhoneSettings().changing { $0.sessionLength = .oneHour; $0.sounds = false }
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(PhoneSettings.self, from: data), original)
    }

    func testAFileWithOnlySomeKeysKeepsTheDefaultsForTheRest() throws {
        let decoded = try JSONDecoder().decode(PhoneSettings.self, from: Data(#"{"language":"es"}"#.utf8))
        XCTAssertEqual(decoded.language, "es")
        XCTAssertEqual(decoded.sessionLength, .fifteenMinutes)
        XCTAssertTrue(decoded.autoEdit)
    }

    func testAnUnknownSessionLengthFallsBackToTheDefault() throws {
        let decoded = try JSONDecoder().decode(PhoneSettings.self, from: Data(#"{"sessionLength":"forever"}"#.utf8))
        XCTAssertEqual(decoded.sessionLength, .fifteenMinutes)
    }

    func testThePipelineLanguageIsNilForAuto() {
        XCTAssertNil(PhoneSettings().pipelineLanguage(resolvedLocale: nil))
        XCTAssertEqual(PhoneSettings().changing { $0.language = "es" }.pipelineLanguage(resolvedLocale: nil), "es")
    }

    func testThePipelineLanguageFollowsTheResolvedLocale() {
        XCTAssertEqual(PhoneSettings().pipelineLanguage(resolvedLocale: "es-MX"), "es")
        XCTAssertEqual(PhoneSettings().changing { $0.language = "en" }.pipelineLanguage(resolvedLocale: "en-US"), "en")
    }
}

final class SharedStoresTests: XCTestCase {
    private var folder: URL!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("shared-stores-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: folder)
    }

    func testEverythingStartsWithDefaults() {
        let stores = SharedStores(folder: folder)
        XCTAssertEqual(stores.settings(), PhoneSettings())
        XCTAssertEqual(stores.dictionary(), PersonalDictionary())
        XCTAssertEqual(stores.snippets(), Snippets())
        XCTAssertEqual(stores.styles(), StyleSettings())
        XCTAssertEqual(stores.history(), [])
        XCTAssertEqual(stores.stats(), UsageStats())
    }

    func testSettingsAreSavedForTheOtherProcess() throws {
        try SharedStores(folder: folder).save(PhoneSettings().changing { $0.haptics = false })
        XCTAssertFalse(SharedStores(folder: folder).settings().haptics)
    }

    func testRecordingADictationAddsHistoryAndStats() throws {
        let stores = SharedStores(folder: folder)
        let item = try stores.recordDictation(text: "hello there friend ", raw: "um hello there friend", seconds: 3, at: now)
        XCTAssertEqual(item?.text, "hello there friend ")
        XCTAssertEqual(stores.history().map(\.text), ["hello there friend "])
        XCTAssertEqual(stores.stats().totalWords, 3)
        XCTAssertEqual(stores.stats().totalSeconds, 3, accuracy: 1e-9)
        XCTAssertEqual(stores.stats().totalSessions, 1)
    }

    func testHistoryOffStillCountsTheStatsButKeepsNoText() throws {
        let stores = SharedStores(folder: folder)
        try stores.save(PhoneSettings().changing { $0.historyEnabled = false })
        let item = try stores.recordDictation(text: "private words here ", raw: "private words here", seconds: 2, at: now)
        XCTAssertNil(item)
        XCTAssertEqual(stores.history(), [])
        XCTAssertEqual(stores.stats().totalWords, 3)
    }

    func testNewestDictationComesFirst() throws {
        let stores = SharedStores(folder: folder)
        _ = try stores.recordDictation(text: "first one ", raw: "first one", seconds: 1, at: now)
        _ = try stores.recordDictation(text: "second one ", raw: "second one", seconds: 1, at: now.addingTimeInterval(60))
        XCTAssertEqual(stores.history().map(\.text), ["second one ", "first one "])
    }

    func testTheHistoryCanBeSavedAfterADelete() throws {
        let stores = SharedStores(folder: folder)
        _ = try stores.recordDictation(text: "first one ", raw: "first one", seconds: 1, at: now)
        _ = try stores.recordDictation(text: "second one ", raw: "second one", seconds: 1, at: now.addingTimeInterval(60))
        let doomed = try XCTUnwrap(stores.history().first)
        try stores.save(History.removing(doomed.id, from: stores.history()))
        XCTAssertEqual(SharedStores(folder: folder).history().map(\.text), ["first one "])
        XCTAssertEqual(stores.stats().totalWords, 4, "the numbers are not taken back")
    }

    func testStatsCanBeSavedForTheSamplePreview() throws {
        let stats = UsageStats().recording(words: 120, seconds: 60, on: DayKey(ordinal: 20_000))
        try SharedStores(folder: folder).save(stats)
        XCTAssertEqual(SharedStores(folder: folder).stats(), stats)
    }

    func testEmptyTextRecordsNothing() throws {
        let stores = SharedStores(folder: folder)
        XCTAssertNil(try stores.recordDictation(text: "  ", raw: "", seconds: 1, at: now))
        XCTAssertEqual(stores.stats(), UsageStats())
    }
}
