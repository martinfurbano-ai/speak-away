import Foundation

/// Some capture paths stop delivering buffers while nothing plays, which would shift every later
/// timestamp earlier. The recorder compares how many samples it has with how many the wall clock says
/// it should have, and inserts silence for the difference, so sample position always equals meeting time.
public enum GapFiller {
    /// How many zero samples to insert before `incoming` arrives. Gaps under `tolerance` seconds are scheduling jitter.
    public static func padding(received: Int, incoming: Int, elapsed: TimeInterval, sampleRate: Int, tolerance: TimeInterval = 1.0) -> Int {
        let expected = Int(elapsed * Double(sampleRate))
        let missing = expected - (received + incoming)
        return missing > Int(tolerance * Double(sampleRate)) ? missing : 0
    }

    public static func silence(count: Int) -> [Float] {
        [Float](repeating: 0, count: max(0, count))
    }
}
