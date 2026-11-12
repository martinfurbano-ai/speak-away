import Foundation

/// Voice loudness for the level bars.
public enum LevelMeter {
    /// Quieter than this reads as silence, louder than `ceilingDB` as full.
    public static let floorDB = -55.0
    public static let ceilingDB = -15.0

    /// 0...1 from an RMS amplitude (1 is full scale), on a decibel scale like the system meters.
    public static func level(rms: Double) -> Double {
        guard !rms.isNaN, rms > 0 else { return 0 }
        let db = 20 * log10(rms)
        return min(1, max(0, (db - floorDB) / (ceilingDB - floorDB)))
    }

    public static func rms(of samples: UnsafeBufferPointer<Float>) -> Double {
        guard !samples.isEmpty else { return 0 }
        var sum = 0.0
        for sample in samples { sum += Double(sample) * Double(sample) }
        return (sum / Double(samples.count)).squareRoot()
    }

    public static func rms(of samples: [Float]) -> Double {
        samples.withUnsafeBufferPointer { rms(of: $0) }
    }
}

/// Smooths the level so the bars rise quickly with the voice and fall back gently.
public struct LevelSmoother: Equatable, Sendable {
    public static let attack = 0.6
    public static let release = 0.15

    public let value: Double

    public init(value: Double = 0) {
        self.value = min(1, max(0, value))
    }

    /// A new smoother one step closer to `level`.
    public func updated(with level: Double) -> LevelSmoother {
        let target = min(1, max(0, level.isNaN ? 0 : level))
        let rate = target > value ? Self.attack : Self.release
        return LevelSmoother(value: value + (target - value) * rate)
    }
}
