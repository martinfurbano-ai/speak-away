import Foundation

/// How the three bars inside the Speak Away bubble move.
/// Heights are a fraction of the tallest bar; `lift` raises a bar, as a fraction of the same height.
public enum BubbleMotion {
    public enum Phase: Sendable { case idle, listening, thinking }

    public struct Bar: Equatable, Sendable {
        public let height: Double
        public let lift: Double
    }

    /// The still logo: a dot, a tall bar and a medium bar (96, 236 and 150 on the 1024 icon).
    public static let logo: [Double] = [96.0 / 236, 1, 150.0 / 236]
    /// A bar as wide as it is tall: the typing dot.
    public static let dot: Double = 84.0 / 236
    public static let maxLift: Double = 0.18
    public static let typingPeriod: Double = 1.2

    private static let weights: [Double] = [0.62, 1, 0.78]

    public static func bars(_ phase: Phase, level: Float, time: Double) -> [Bar] {
        switch phase {
        case .idle:
            return logo.map { Bar(height: $0, lift: 0) }
        case .listening:
            let loud = Double(min(max(level, 0), 1))
            let raw = weights.indices.map { i -> Double in
                let wobble = 0.775 + 0.225 * sin(time * 7 + Double(i) * 1.9)
                return dot + (1 - dot) * loud * weights[i] * (i == 1 ? 1 : wobble)
            }
            let middle = raw[1]
            return raw.enumerated().map { i, h in Bar(height: i == 1 ? h : min(h, middle), lift: 0) }
        case .thinking:
            return (0..<3).map { i in
                let wave = sin(2 * Double.pi * time / typingPeriod - Double(i) * 0.9)
                return Bar(height: dot, lift: maxLift * max(0, wave))
            }
        }
    }
}
