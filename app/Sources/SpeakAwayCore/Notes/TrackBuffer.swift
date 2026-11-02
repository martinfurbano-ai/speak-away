import Foundation

/// The audio of one track (mic or call) waiting to be cut into chunks.
///
/// Audio callbacks append from their own thread, a timer takes finished chunks from another, so the
/// state sits behind a lock. Chunk start times are seconds from the start of the meeting: samples are
/// counted from the first buffer, gaps are filled with silence (`GapFiller`), and the first buffer's
/// arrival time says how long after the meeting began the track started.
public final class TrackBuffer: @unchecked Sendable {
    public struct Chunk: Equatable, Sendable {
        public let start: TimeInterval
        public let audio: [Float]
    }

    private let lock = NSLock()
    private let meetingStart: Date
    private let sampleRate: Int
    private let chunker: Chunker
    private var samples: [Float] = []
    private var dropped = 0
    private var received = 0
    private var trackStart: Date?
    private var loudest: Float = 0

    public init(meetingStart: Date, sampleRate: Int = 16_000, chunker: Chunker = Chunker()) {
        self.meetingStart = meetingStart
        self.sampleRate = sampleRate
        self.chunker = chunker
    }

    /// Loudest real sample so far. Inserted silence does not count.
    public var peak: Float {
        lock.lock(); defer { lock.unlock() }
        return loudest
    }

    /// `now` is when the buffer arrived, which is the moment its last sample was captured.
    public func append(_ incoming: [Float], at now: Date) {
        guard !incoming.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }
        let duration = Double(incoming.count) / Double(sampleRate)
        let origin = trackStart ?? now.addingTimeInterval(-duration)
        trackStart = origin
        let pad = GapFiller.padding(received: received, incoming: incoming.count, elapsed: now.timeIntervalSince(origin), sampleRate: sampleRate)
        if pad > 0 { samples.append(contentsOf: GapFiller.silence(count: pad)) }
        samples.append(contentsOf: incoming)
        received += pad + incoming.count
        loudest = max(loudest, incoming.reduce(Float(0)) { max($0, abs($1)) })
    }

    /// Chunks that are ready. With `flush`, whatever is left too, because the meeting ended.
    public func takeChunks(flush: Bool = false) -> [Chunk] {
        lock.lock(); defer { lock.unlock() }
        guard let trackStart else { return [] }
        let offset = trackStart.timeIntervalSince(meetingStart)
        var cuts = chunker.cuts(in: samples)
        if flush, (cuts.last ?? 0) < samples.count { cuts.append(samples.count) }
        var chunks: [Chunk] = []
        var cursor = 0
        for cut in cuts {
            chunks.append(Chunk(start: offset + Double(dropped + cursor) / Double(sampleRate), audio: Array(samples[cursor..<cut])))
            cursor = cut
        }
        if cursor > 0 {
            samples = Array(samples[cursor...])
            dropped += cursor
        }
        return chunks
    }
}
