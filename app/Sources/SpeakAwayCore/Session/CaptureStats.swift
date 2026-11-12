import Foundation

/// What was measured while a dictation was being recorded, so SpeechGate can judge it without keeping
/// the audio (on the iPhone the sound is never stored). Values are never changed: `adding` returns a new one.
public struct CaptureStats: Equatable, Sendable {
    public let seconds: Double
    public let peak: Float

    public init(seconds: Double = 0, peak: Float = 0) {
        self.seconds = seconds
        self.peak = peak
    }

    /// Adds one buffer of `frames` samples at `sampleRate` with its loudest sample `peak` (0...1).
    /// The rate may change between buffers (a route change from the built-in mic to Bluetooth), so
    /// time is added as seconds, not as a count of samples.
    public func adding(frames: Int, sampleRate: Double, peak chunkPeak: Float) -> CaptureStats {
        guard frames > 0, sampleRate > 0, sampleRate.isFinite else { return self }
        let loud = chunkPeak.isFinite ? abs(chunkPeak) : 0
        return CaptureStats(seconds: seconds + Double(frames) / sampleRate, peak: max(peak, loud))
    }

    public var verdict: SpeechGate.Verdict { SpeechGate.check(duration: seconds, peak: peak) }
}
