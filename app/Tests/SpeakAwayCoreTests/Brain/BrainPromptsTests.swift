import XCTest
@testable import SpeakAwayCore

final class BrainPromptsTests: XCTestCase {
    func testLanguageNames() {
        XCTAssertEqual(BrainPrompts.languageName("es"), "español")
        XCTAssertEqual(BrainPrompts.languageName("en"), "English")
        XCTAssertNil(BrainPrompts.languageName(nil))
        XCTAssertNil(BrainPrompts.languageName("auto"))
        XCTAssertNil(BrainPrompts.languageName("xx"))
    }

    func testPolishNeverAddsContentAndKeepsLanguage() {
        let p = BrainPrompts.polish(text: "eh hola carla te mando la cotizacion", style: "formal", language: "es")
        XCTAssertTrue(p.instructions.contains("español"))
        XCTAssertTrue(p.instructions.lowercased().contains("do not add"))
        XCTAssertTrue(p.instructions.contains("formal"))
        XCTAssertTrue(p.prompt.contains("te mando la cotizacion"))
    }

    func testPolishWithoutLanguageSaysKeepTheSameLanguage() {
        let p = BrainPrompts.polish(text: "hello", style: "", language: nil)
        XCTAssertTrue(p.instructions.contains("same language"))
        XCTAssertFalse(p.instructions.contains("Style:"))
    }

    func testCommandCarriesInstructionAndSelection() {
        let p = BrainPrompts.command(instruction: "hazlo más formal", selected: "oye mandame eso", language: "es")
        XCTAssertTrue(p.prompt.contains("hazlo más formal"))
        XCTAssertTrue(p.prompt.contains("oye mandame eso"))
        XCTAssertTrue(p.instructions.contains("only the resulting text"))
    }

    func testChunkSummaryAndMergePrompts() {
        let c = BrainPrompts.chunkSummary(transcript: "Ana: vamos a lanzar el lunes", language: "es", part: 2, of: 3)
        XCTAssertTrue(c.prompt.contains("vamos a lanzar el lunes"))
        XCTAssertTrue(c.instructions.contains("part 2 of 3"))
        let m = BrainPrompts.mergeSummaries(["uno", "dos"], language: nil)
        XCTAssertTrue(m.prompt.contains("uno"))
        XCTAssertTrue(m.prompt.contains("dos"))
    }
}

final class BrainGuardTests: XCTestCase {
    func testPolishRejectsEmptyOrBloatedAnswers() {
        XCTAssertEqual(BrainGuard.acceptPolish(original: "hola carla", candidate: "  "), "hola carla")
        XCTAssertEqual(BrainGuard.acceptPolish(original: "hola", candidate: String(repeating: "x", count: 400)), "hola")
        XCTAssertEqual(BrainGuard.acceptPolish(original: "hola carla eh", candidate: "Hola, Carla.\n"), "Hola, Carla.")
    }

    func testPolishStripsWrappingQuotes() {
        XCTAssertEqual(BrainGuard.acceptPolish(original: "hola carla", candidate: "\"Hola, Carla.\""), "Hola, Carla.")
    }

    func testCommandOnlyRejectsEmpty() {
        XCTAssertNil(BrainGuard.acceptCommand(" \n"))
        XCTAssertEqual(BrainGuard.acceptCommand("  Dear Carla,\n"), "Dear Carla,")
    }

    func testLimitsScaleWithTheContextWindow() {
        XCTAssertGreaterThan(BrainLimits.maxCommandChars(contextTokens: 4096), 2000)
        XCTAssertLessThan(BrainLimits.maxCommandChars(contextTokens: 4096), BrainLimits.maxChunkChars(contextTokens: 4096))
        XCTAssertGreaterThan(BrainLimits.maxChunkChars(contextTokens: 8192), BrainLimits.maxChunkChars(contextTokens: 4096))
        XCTAssertGreaterThan(BrainLimits.maxChunkChars(contextTokens: 10), 0)
    }
}
