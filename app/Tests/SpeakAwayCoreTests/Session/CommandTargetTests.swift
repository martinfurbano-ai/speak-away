import XCTest
@testable import SpeakAwayCore

final class CommandTargetTests: XCTestCase {
    // MARK: with a selection

    func testSelectionIsTheTextAndNothingIsDeleted() throws {
        let target = try XCTUnwrap(CommandTarget.resolve(selectedText: "send me the file", documentContextBeforeInput: "Hi Ana. "))
        XCTAssertEqual(target.text, "send me the file")
        XCTAssertEqual(target.deleteBackward, 0)
    }

    func testSelectionWinsOverTheContext() throws {
        let target = try XCTUnwrap(CommandTarget.resolve(selectedText: "second", documentContextBeforeInput: "First. Second"))
        XCTAssertEqual(target.text, "second")
        XCTAssertEqual(target.deleteBackward, 0)
    }

    func testSelectionKeepsItsOuterWhitespaceForTheReplacement() throws {
        let target = try XCTUnwrap(CommandTarget.resolve(selectedText: "  hello world\n", documentContextBeforeInput: nil))
        XCTAssertEqual(target.text, "hello world")
        XCTAssertEqual(target.deleteBackward, 0)
        XCTAssertEqual(target.replacement(for: "Hello, world!"), "  Hello, world!\n")
    }

    func testBlankSelectionHasNothingToRewrite() {
        XCTAssertNil(CommandTarget.resolve(selectedText: "   ", documentContextBeforeInput: "Hello there."))
        XCTAssertNil(CommandTarget.resolve(selectedText: "\n", documentContextBeforeInput: nil))
    }

    // MARK: without a selection

    func testLastSentenceBeforeTheCursor() throws {
        let target = try XCTUnwrap(CommandTarget.resolve(selectedText: nil, documentContextBeforeInput: "Hi Ana. Can you send me the file?"))
        XCTAssertEqual(target.text, "Can you send me the file?")
        XCTAssertEqual(target.deleteBackward, "Can you send me the file?".count)
    }

    func testEmptySelectionCountsAsNoSelection() throws {
        let target = try XCTUnwrap(CommandTarget.resolve(selectedText: "", documentContextBeforeInput: "One. Two."))
        XCTAssertEqual(target.text, "Two.")
        XCTAssertEqual(target.deleteBackward, 4)
    }

    func testASingleSentenceIsTakenWhole() throws {
        let target = try XCTUnwrap(CommandTarget.resolve(selectedText: nil, documentContextBeforeInput: "thanks for the help"))
        XCTAssertEqual(target.text, "thanks for the help")
        XCTAssertEqual(target.deleteBackward, 19)
    }

    func testTrailingSpaceIsDeletedAndKeptForTheReplacement() throws {
        let target = try XCTUnwrap(CommandTarget.resolve(selectedText: nil, documentContextBeforeInput: "Hi Ana. Send it now. "))
        XCTAssertEqual(target.text, "Send it now.")
        XCTAssertEqual(target.deleteBackward, "Send it now. ".count)
        XCTAssertEqual(target.replacement(for: "Please send it."), "Please send it. ")
    }

    func testNewlineStartsANewSentence() throws {
        let target = try XCTUnwrap(CommandTarget.resolve(selectedText: nil, documentContextBeforeInput: "Dear Ana\nsend me the file"))
        XCTAssertEqual(target.text, "send me the file")
        XCTAssertEqual(target.deleteBackward, 16)
    }

    func testTrailingNewlineIsKeptForTheReplacement() throws {
        let target = try XCTUnwrap(CommandTarget.resolve(selectedText: nil, documentContextBeforeInput: "Dear Ana\nsend me the file\n"))
        XCTAssertEqual(target.text, "send me the file")
        XCTAssertEqual(target.deleteBackward, 17)
        XCTAssertEqual(target.replacement(for: "Send me the file."), "Send me the file.\n")
    }

    func testQuestionAndExclamationEndASentence() throws {
        let one = try XCTUnwrap(CommandTarget.resolve(selectedText: nil, documentContextBeforeInput: "Really? Yes! see you tomorrow"))
        XCTAssertEqual(one.text, "see you tomorrow")
        let two = try XCTUnwrap(CommandTarget.resolve(selectedText: nil, documentContextBeforeInput: "¿Vienes? ¡Claro! nos vemos"))
        XCTAssertEqual(two.text, "nos vemos")
    }

    func testDecimalsAndInnerDotsDoNotSplit() throws {
        let target = try XCTUnwrap(CommandTarget.resolve(selectedText: nil, documentContextBeforeInput: "Ok. It costs 3.5 dollars and ana@mail.com wrote"))
        XCTAssertEqual(target.text, "It costs 3.5 dollars and ana@mail.com wrote")
    }

    func testEndingPunctuationBelongsToTheSentence() throws {
        let target = try XCTUnwrap(CommandTarget.resolve(selectedText: nil, documentContextBeforeInput: "One. Two... Three?!"))
        XCTAssertEqual(target.text, "Three?!")
        XCTAssertEqual(target.deleteBackward, 7)
    }

    func testClosingQuoteAfterThePeriodStaysWithItsSentence() throws {
        let target = try XCTUnwrap(CommandTarget.resolve(selectedText: nil, documentContextBeforeInput: "He said \"go.\" Then I left"))
        XCTAssertEqual(target.text, "Then I left")
    }

    func testCountsUserPerceivedCharacters() throws {
        let target = try XCTUnwrap(CommandTarget.resolve(selectedText: nil, documentContextBeforeInput: "Hi. Gracias 🙏🏽 amigo"))
        XCTAssertEqual(target.text, "Gracias 🙏🏽 amigo")
        XCTAssertEqual(target.deleteBackward, "Gracias 🙏🏽 amigo".count)
    }

    func testNothingBeforeTheCursorMeansNothingToRewrite() {
        XCTAssertNil(CommandTarget.resolve(selectedText: nil, documentContextBeforeInput: nil))
        XCTAssertNil(CommandTarget.resolve(selectedText: nil, documentContextBeforeInput: ""))
        XCTAssertNil(CommandTarget.resolve(selectedText: nil, documentContextBeforeInput: "  \n "))
    }

    // MARK: replacement

    func testReplacementTrimsTheModelAnswer() throws {
        let target = try XCTUnwrap(CommandTarget.resolve(selectedText: nil, documentContextBeforeInput: "Hi. send it "))
        XCTAssertEqual(target.replacement(for: "\nPlease send it.\n"), "Please send it. ")
    }
}
