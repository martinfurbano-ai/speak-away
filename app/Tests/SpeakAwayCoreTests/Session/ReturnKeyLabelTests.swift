import XCTest
@testable import SpeakAwayCore

final class ReturnKeyLabelTests: XCTestCase {
    // UIReturnKeyType raw values: default 0, go 1, google 2, join 3, next 4, route 5, search 6,
    // send 7, yahoo 8, done 9, emergencyCall 10, continue 11.

    func testTheDefaultKeyIsReturn() {
        XCTAssertEqual(ReturnKeyLabel.catalogKey(returnKeyType: 0), "return")
    }

    func testSendGoDoneAndNext() {
        XCTAssertEqual(ReturnKeyLabel.catalogKey(returnKeyType: 7), "send")
        XCTAssertEqual(ReturnKeyLabel.catalogKey(returnKeyType: 1), "go")
        XCTAssertEqual(ReturnKeyLabel.catalogKey(returnKeyType: 9), "done")
        XCTAssertEqual(ReturnKeyLabel.catalogKey(returnKeyType: 4), "next")
    }

    func testSearchGoogleAndYahooAreAllSearch() {
        for raw in [6, 2, 8] {
            XCTAssertEqual(ReturnKeyLabel.catalogKey(returnKeyType: raw), "search", "return key \(raw)")
        }
    }

    func testTheRestOfTheNamedKeys() {
        XCTAssertEqual(ReturnKeyLabel.catalogKey(returnKeyType: 3), "join")
        XCTAssertEqual(ReturnKeyLabel.catalogKey(returnKeyType: 5), "route")
        XCTAssertEqual(ReturnKeyLabel.catalogKey(returnKeyType: 11), "continue")
        XCTAssertEqual(ReturnKeyLabel.catalogKey(returnKeyType: 10), "call")
    }

    func testUnknownValuesFallBackToReturn() {
        for raw in [-1, 12, 99, 1000] {
            XCTAssertEqual(ReturnKeyLabel.catalogKey(returnKeyType: raw), "return", "return key \(raw)")
        }
    }

    func testOnlyTheDefaultAndUnknownKeysArePlain() {
        XCTAssertTrue(ReturnKeyLabel.isPlain(returnKeyType: 0))
        XCTAssertTrue(ReturnKeyLabel.isPlain(returnKeyType: 99))
        for raw in 1...11 {
            XCTAssertFalse(ReturnKeyLabel.isPlain(returnKeyType: raw), "return key \(raw)")
        }
    }

    func testEveryKeyIsLowercaseSoItMatchesTheKeyCaps() {
        for raw in -1...12 {
            let key = ReturnKeyLabel.catalogKey(returnKeyType: raw)
            XCTAssertEqual(key, key.lowercased(), "return key \(raw)")
        }
    }
}
