import XCTest
@testable import SpeakAwayCore

final class GapFillerTests: XCTestCase {
    let rate = 16_000

    func testNoPaddingWhenInSync() {
        XCTAssertEqual(GapFiller.padding(received: 160_000, incoming: 1_600, elapsed: 10.1, sampleRate: rate), 0)
    }

    func testSmallJitterIsTolerated() {
        XCTAssertEqual(GapFiller.padding(received: 160_000, incoming: 1_600, elapsed: 10.6, sampleRate: rate), 0)
    }

    func testBigGapIsFilledWithSilence() {
        // 5 s of samples are missing: the stream stopped delivering while nothing played.
        let zeros = GapFiller.padding(received: 160_000, incoming: 1_600, elapsed: 15.1, sampleRate: rate)
        XCTAssertEqual(Double(zeros) / Double(rate), 5.0, accuracy: 0.05)
    }

    func testNeverNegative() {
        XCTAssertEqual(GapFiller.padding(received: 400_000, incoming: 1_600, elapsed: 3, sampleRate: rate), 0)
    }

    func testSilenceIsExactlyZero() {
        XCTAssertEqual(GapFiller.silence(count: 3), [0, 0, 0])
    }
}
