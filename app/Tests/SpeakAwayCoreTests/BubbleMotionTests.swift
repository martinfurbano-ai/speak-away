import XCTest
@testable import SpeakAwayCore

final class BubbleMotionTests: XCTestCase {
    func testIdleIsTheLogo() {
        let bars = BubbleMotion.bars(.idle, level: 0, time: 12.3)
        XCTAssertEqual(bars.map(\.height), BubbleMotion.logo)
        XCTAssertEqual(bars.map(\.lift), [0, 0, 0])
    }

    func testListeningInSilenceShowsThreeDots() {
        let bars = BubbleMotion.bars(.listening, level: 0, time: 3)
        XCTAssertEqual(bars.count, 3)
        for bar in bars { XCTAssertEqual(bar.height, BubbleMotion.dot, accuracy: 0.0001) }
    }

    func testListeningLoudGrowsTheMiddleBarMost() {
        for time in stride(from: 0.0, to: 2.0, by: 0.13) {
            let bars = BubbleMotion.bars(.listening, level: 1, time: time)
            XCTAssertGreaterThanOrEqual(bars[1].height, bars[0].height)
            XCTAssertGreaterThanOrEqual(bars[1].height, bars[2].height)
            for bar in bars { XCTAssertLessThanOrEqual(bar.height, 1); XCTAssertGreaterThanOrEqual(bar.height, BubbleMotion.dot) }
        }
    }

    func testThinkingIsTypingDotsThatBounceInTurn() {
        var sawDifferentLifts = false
        for time in stride(from: 0.0, to: BubbleMotion.typingPeriod, by: 0.05) {
            let bars = BubbleMotion.bars(.thinking, level: 0.8, time: time)
            for bar in bars {
                XCTAssertEqual(bar.height, BubbleMotion.dot, accuracy: 0.0001)
                XCTAssertGreaterThanOrEqual(bar.lift, 0)
                XCTAssertLessThanOrEqual(bar.lift, BubbleMotion.maxLift)
            }
            if Set(bars.map(\.lift)).count > 1 { sawDifferentLifts = true }
        }
        XCTAssertTrue(sawDifferentLifts, "the dots should not move together")
    }

    func testOutOfRangeLevelIsClamped() {
        let loud = BubbleMotion.bars(.listening, level: 7, time: 1)
        let quiet = BubbleMotion.bars(.listening, level: -2, time: 1)
        XCTAssertEqual(loud.map(\.height), BubbleMotion.bars(.listening, level: 1, time: 1).map(\.height))
        XCTAssertEqual(quiet.map(\.height), BubbleMotion.bars(.listening, level: 0, time: 1).map(\.height))
    }
}
