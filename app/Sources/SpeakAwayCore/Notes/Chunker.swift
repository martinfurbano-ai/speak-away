import Foundation

/// Decides where to cut a growing 16 kHz buffer into chunks for Whisper.
///
/// Whisper works best on about 20 s of audio cut in a pause, never in the middle of a word.
/// The rule: wait for at least 20 s, then cut at the quietest-enough window closest to 20 s that
/// lies between 12 s and 28 s. With no pause by 30 s, take a pause in the last two seconds if there
/// is one, otherwise cut hard at 30 s. Pure and stateless: the caller keeps the buffer and the
/// start index of the part that has not been cut yet.
public struct Chunker: Equatable, Sendable {
    public var sampleRate: Int
    public var minSeconds: Double
    public var targetSeconds: Double
    public var maxSoftSeconds: Double
    public var hardSeconds: Double
    /// A window with an RMS under this level counts as a pause.
    public var silenceRMS: Float
    public var windowSeconds: Double

    public init(
        sampleRate: Int = 16_000,
        minSeconds: Double = 12,
        targetSeconds: Double = 20,
        maxSoftSeconds: Double = 28,
        hardSeconds: Double = 30,
        silenceRMS: Float = 0.01,
        windowSeconds: Double = 0.1
    ) {
        self.sampleRate = sampleRate
        self.minSeconds = minSeconds
        self.targetSeconds = targetSeconds
        self.maxSoftSeconds = maxSoftSeconds
        self.hardSeconds = hardSeconds
        self.silenceRMS = silenceRMS
        self.windowSeconds = windowSeconds
    }

    /// The index (exclusive end of the chunk) where the audio that starts at `start` should be cut, or nil to keep waiting.
    public func nextCut(in buffer: [Float], from start: Int) -> Int? {
        let available = buffer.count - start
        let window = max(1, Int(windowSeconds * Double(sampleRate)))
        let target = Int(targetSeconds * Double(sampleRate))
        let low = Int(minSeconds * Double(sampleRate))
        let soft = Int(maxSoftSeconds * Double(sampleRate))
        let hard = Int(hardSeconds * Double(sampleRate))
        guard start >= 0, available >= target else { return nil }

        // Window centres (relative to start) that are quiet, scanned in steps of one window.
        func quietCentres(from lo: Int, through hi: Int) -> [Int] {
            let last = min(hi, available - window / 2)
            guard last >= lo else { return [] }
            var centres: [Int] = []
            var centre = lo
            while centre <= last {
                let from = start + centre - window / 2
                let to = from + window
                if from >= start, to <= buffer.count, Chunker.rms(buffer[from..<to]) < silenceRMS { centres.append(centre) }
                centre += window
            }
            return centres
        }

        let primary = quietCentres(from: low, through: soft)
        if let best = primary.min(by: { abs($0 - target) < abs($1 - target) }) { return start + best }
        guard available >= hard else { return nil }
        if let late = quietCentres(from: soft + 1, through: hard).first { return start + late }
        return start + hard
    }

    /// Every cut that can be decided now, in order. The tail after the last cut is not ready yet.
    public func cuts(in buffer: [Float], from start: Int = 0) -> [Int] {
        var result: [Int] = []
        var cursor = start
        while let cut = nextCut(in: buffer, from: cursor), cut > cursor {
            result.append(cut)
            cursor = cut
        }
        return result
    }

    public static func rms(_ samples: ArraySlice<Float>) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sum = samples.reduce(Float(0)) { $0 + $1 * $1 }
        return (sum / Float(samples.count)).squareRoot()
    }
}
