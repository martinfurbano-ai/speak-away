import XCTest
@testable import SpeakAwayCore

final class ChunkerTests: XCTestCase {
    let rate = 16_000
    let chunker = Chunker()

    /// Loud "speech" with optional silent gaps given as (startSecond, endSecond).
    func audio(seconds: Double, silences: [(Double, Double)] = []) -> [Float] {
        let count = Int(seconds * Double(rate))
        var out = [Float](repeating: 0.2, count: count)
        for (a, b) in silences {
            let lo = Int(a * Double(rate)), hi = min(count, Int(b * Double(rate)))
            for i in lo..<hi { out[i] = 0.0005 }
        }
        return out
    }

    func testNoCutBeforeTheMinimum() {
        XCTAssertNil(chunker.nextCut(in: audio(seconds: 11.9, silences: [(5, 6)]), from: 0))
    }

    func testNoCutWhileWaitingForABetterSilence() {
        // 25 s of speech with no pause yet: wait, the hard limit is 30 s.
        XCTAssertNil(chunker.nextCut(in: audio(seconds: 25), from: 0))
    }

    func testCutsAtTheSilenceClosestToTwentySeconds() {
        let buffer = audio(seconds: 27, silences: [(14, 14.5), (19.5, 20.5), (26, 26.5)])
        let cut = try! XCTUnwrap(chunker.nextCut(in: buffer, from: 0))
        XCTAssertEqual(Double(cut) / Double(rate), 20.0, accuracy: 0.6)
    }

    func testIgnoresSilenceBeforeTwelveSeconds() {
        let buffer = audio(seconds: 21, silences: [(8, 9)])
        XCTAssertNil(chunker.nextCut(in: buffer, from: 0))
    }

    func testIgnoresSilenceAfterTwentyEightSecondsWhenOneExistsInside() {
        let buffer = audio(seconds: 29.5, silences: [(15, 15.4), (29, 29.4)])
        let cut = try! XCTUnwrap(chunker.nextCut(in: buffer, from: 0))
        XCTAssertEqual(Double(cut) / Double(rate), 15.2, accuracy: 0.3)
    }

    func testHardCutAtThirtySecondsWithoutAnySilence() {
        let cut = chunker.nextCut(in: audio(seconds: 31), from: 0)
        XCTAssertEqual(cut, 30 * rate)
    }

    func testCutsLaterThanTwentyEightOnlyAsLastResortSilence() {
        let buffer = audio(seconds: 30.5, silences: [(29, 29.4)])
        let cut = try! XCTUnwrap(chunker.nextCut(in: buffer, from: 0))
        XCTAssertEqual(Double(cut) / Double(rate), 29.2, accuracy: 0.3)
    }

    func testStartOffsetIsRespected() {
        let buffer = audio(seconds: 50, silences: [(34, 34.5)])
        let cut = try! XCTUnwrap(chunker.nextCut(in: buffer, from: 20 * rate))
        XCTAssertEqual(Double(cut) / Double(rate), 34.25, accuracy: 0.3)
        XCTAssertGreaterThan(cut, 20 * rate)
    }

    func testCutsWalksTheWholeBufferAndLeavesTheTail() {
        let buffer = audio(seconds: 75)
        let cuts = chunker.cuts(in: buffer)
        XCTAssertEqual(cuts, [30 * rate, 60 * rate])
    }

    func testDoesNotMutateInput() {
        let buffer = audio(seconds: 31)
        let copy = buffer
        _ = chunker.cuts(in: buffer)
        XCTAssertEqual(buffer, copy)
    }

    func testEmptyBuffer() {
        XCTAssertNil(chunker.nextCut(in: [], from: 0))
        XCTAssertEqual(chunker.cuts(in: []), [])
    }

    func testRMS() {
        XCTAssertEqual(Chunker.rms([0.5, -0.5, 0.5, -0.5][...]), 0.5, accuracy: 0.0001)
        XCTAssertEqual(Chunker.rms([Float]()[...]), 0)
    }
}
