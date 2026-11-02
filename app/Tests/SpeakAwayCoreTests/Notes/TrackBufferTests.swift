import XCTest
@testable import SpeakAwayCore

final class TrackBufferTests: XCTestCase {
    let rate = 16_000
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    func loud(_ seconds: Double) -> [Float] { [Float](repeating: 0.2, count: Int(seconds * Double(rate))) }

    func testNothingToTakeBeforeTwentySeconds() {
        let track = TrackBuffer(meetingStart: t0)
        track.append(loud(10), at: t0.addingTimeInterval(10))
        XCTAssertEqual(track.takeChunks(), [])
    }

    func testChunkStartsAreMeetingTimeAndTheFirstBufferOffsetsTheTrack() {
        let track = TrackBuffer(meetingStart: t0)
        // 31 s of audio that arrives at second 33: the track started 2 s into the meeting.
        track.append(loud(31), at: t0.addingTimeInterval(33))
        let first = track.takeChunks()
        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(first[0].start, 2.0, accuracy: 0.001)
        XCTAssertEqual(first[0].audio.count, 30 * rate)
        let rest = track.takeChunks(flush: true)
        XCTAssertEqual(rest.count, 1)
        XCTAssertEqual(rest[0].start, 32.0, accuracy: 0.001)
        XCTAssertEqual(rest[0].audio.count, rate)
        XCTAssertEqual(track.takeChunks(flush: true), [])
    }

    func testGapIsFilledWithSilenceSoTimestampsStayTrue() {
        let track = TrackBuffer(meetingStart: t0)
        track.append(loud(1), at: t0.addingTimeInterval(1))
        track.append(loud(1), at: t0.addingTimeInterval(10)) // 8 s of nothing arrived in between
        let all = track.takeChunks(flush: true)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].audio.count, 10 * rate, accuracy: rate / 10)
    }

    func testPeakIgnoresInsertedSilence() {
        let track = TrackBuffer(meetingStart: t0)
        XCTAssertEqual(track.peak, 0)
        track.append([0, 0, 0.4, -0.7], at: t0.addingTimeInterval(1))
        XCTAssertEqual(track.peak, 0.7, accuracy: 0.0001)
    }

    func testFlushOnEmptyTrack() {
        XCTAssertEqual(TrackBuffer(meetingStart: t0).takeChunks(flush: true), [])
    }

    func testChunkCutsInAPause() {
        let track = TrackBuffer(meetingStart: t0)
        var audio = loud(26)
        for i in Int(19.5 * Double(rate))..<Int(20.5 * Double(rate)) { audio[i] = 0 }
        track.append(audio, at: t0.addingTimeInterval(26))
        let chunk = track.takeChunks()
        XCTAssertEqual(chunk.count, 1)
        XCTAssertEqual(Double(chunk[0].audio.count) / Double(rate), 20.0, accuracy: 0.6)
    }
}

private func XCTAssertEqual(_ a: Int, _ b: Int, accuracy: Int, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertLessThanOrEqual(abs(a - b), accuracy, "\(a) vs \(b)", file: file, line: line)
}
