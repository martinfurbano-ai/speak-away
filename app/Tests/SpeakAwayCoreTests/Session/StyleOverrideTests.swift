import XCTest
@testable import SpeakAwayCore

final class StyleOverrideTests: XCTestCase {
    func testTheChipCyclesThroughEveryStyleAndBackToAutomatic() {
        var current: WritingStyle?
        var seen: [WritingStyle?] = []
        for _ in 0..<4 {
            current = StyleOverride.next(after: current)
            seen.append(current)
        }
        XCTAssertEqual(seen, [.formal, .casual, .veryCasual, nil])
    }

    func testEveryStyleIsReachable() {
        var reached = Set<WritingStyle>()
        var current: WritingStyle?
        for _ in 0..<10 {
            current = StyleOverride.next(after: current)
            if let current { reached.insert(current) }
        }
        XCTAssertEqual(reached, Set(WritingStyle.allCases))
    }

    func testTitlesAreShortAndDistinct() {
        let titles = WritingStyle.allCases.map(StyleOverride.title)
        XCTAssertEqual(Set(titles).count, WritingStyle.allCases.count)
        XCTAssertTrue(titles.allSatisfy { !$0.isEmpty && $0.count <= 12 })
    }

    func testTheChipTextShowsTheEffectiveStyleAndWhetherItIsPicked() {
        let auto = StyleOverride.chipText(override: nil, effective: .casual)
        let picked = StyleOverride.chipText(override: .casual, effective: .casual)
        XCTAssertNotEqual(auto, picked)
        XCTAssertTrue(auto.contains(StyleOverride.title(.casual)))
        XCTAssertTrue(picked.contains(StyleOverride.title(.casual)))
    }
}
