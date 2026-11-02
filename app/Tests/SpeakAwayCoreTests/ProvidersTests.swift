import XCTest
@testable import SpeakAwayCore

/// Same contract as speakaway/providers.py: Speak Away never needs a key.
final class ProvidersTests: XCTestCase {
    func testNoKeysMeansEverythingLocal() {
        XCTAssertEqual(Providers.resolve(stt: "auto", brain: "auto", keys: []), .init(stt: "local", brain: "none"))
    }

    func testAutoKeepsDictationLocalAndUsesAKeyOnlyForTheBrain() {
        XCTAssertEqual(Providers.resolve(stt: "auto", brain: "auto", keys: ["groq"]), .init(stt: "local", brain: "groq"))
    }

    func testCloudDictationOnlyWhenChosenOnPurpose() {
        XCTAssertEqual(Providers.resolve(stt: "groq", brain: "auto", keys: ["groq"]), .init(stt: "groq", brain: "groq"))
    }

    func testChoiceWithoutItsKeyFallsBackToLocal() {
        XCTAssertEqual(Providers.resolve(stt: "openai", brain: "anthropic", keys: []), .init(stt: "local", brain: "none"))
    }

    func testMcpBrainNeverNeedsAKey() {
        XCTAssertEqual(Providers.resolve(stt: "auto", brain: "mcp", keys: []), .init(stt: "local", brain: "mcp"))
    }
}
