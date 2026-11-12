import XCTest
@testable import SpeakAwayCore

final class LevelMeterTests: XCTestCase {
    func testSilenceReadsZero() {
        XCTAssertEqual(LevelMeter.level(rms: 0), 0)
        XCTAssertEqual(LevelMeter.level(rms: 0.0001), 0)
    }

    func testFullScaleReadsOne() {
        XCTAssertEqual(LevelMeter.level(rms: 1), 1)
        XCTAssertEqual(LevelMeter.level(rms: 5), 1)
    }

    func testNegativeOrNotANumberReadsZero() {
        XCTAssertEqual(LevelMeter.level(rms: -0.5), 0)
        XCTAssertEqual(LevelMeter.level(rms: .nan), 0)
    }

    func testLouderIsNeverQuieter() {
        var previous = -1.0
        for rms in stride(from: 0.0005, through: 0.5, by: 0.0005) {
            let level = LevelMeter.level(rms: rms)
            XCTAssertGreaterThanOrEqual(level, previous)
            XCTAssertTrue((0...1).contains(level))
            previous = level
        }
    }

    func testNormalSpeechLandsInTheMiddleOfTheRange() {
        // About -26 dBFS is a voice at arm's length.
        let level = LevelMeter.level(rms: 0.05)
        XCTAssertGreaterThan(level, 0.4)
        XCTAssertLessThan(level, 0.9)
    }

    func testRMSOfASquareWaveIsItsAmplitude() {
        let samples = [Float](repeating: 0.25, count: 100) + [Float](repeating: -0.25, count: 100)
        XCTAssertEqual(LevelMeter.rms(of: samples), 0.25, accuracy: 1e-6)
    }

    func testRMSOfNothingIsZero() {
        XCTAssertEqual(LevelMeter.rms(of: []), 0)
    }

    // MARK: Smoothing

    func testSmootherStartsAtZero() {
        XCTAssertEqual(LevelSmoother().value, 0)
    }

    func testSmootherRisesFasterThanItFalls() {
        let up = LevelSmoother().updated(with: 1).value
        let down = LevelSmoother(value: 1).updated(with: 0).value
        XCTAssertGreaterThan(up, 1 - down)
    }

    func testSmootherMovesTowardTheTargetWithoutOvershooting() {
        var smoother = LevelSmoother()
        for _ in 0..<50 {
            smoother = smoother.updated(with: 0.6)
            XCTAssertLessThanOrEqual(smoother.value, 0.6 + 1e-9)
        }
        XCTAssertEqual(smoother.value, 0.6, accuracy: 0.01)
    }

    func testSmootherFallsBackToSilence() {
        var smoother = LevelSmoother(value: 1)
        for _ in 0..<80 { smoother = smoother.updated(with: 0) }
        XCTAssertLessThan(smoother.value, 0.01)
    }

    func testSmootherKeepsTheValueBetweenZeroAndOne() {
        XCTAssertEqual(LevelSmoother(value: 5).value, 1)
        XCTAssertEqual(LevelSmoother(value: -1).value, 0)
        XCTAssertLessThanOrEqual(LevelSmoother().updated(with: 9).value, 1)
        XCTAssertGreaterThanOrEqual(LevelSmoother().updated(with: -9).value, 0)
    }

    func testUpdatingReturnsANewSmootherAndKeepsTheOldOne() {
        let first = LevelSmoother()
        _ = first.updated(with: 1)
        XCTAssertEqual(first.value, 0)
    }
}
