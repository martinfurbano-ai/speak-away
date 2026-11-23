import Foundation

/// Picks the dictation language when the setting is Automatic.
/// Whisper's own detector can choose any of 99 languages, and short clips of Spanish or
/// mixed speech often land on a wrong one. Dictation only needs Spanish or English.
public enum DictationLanguage {
    public static let candidates = ["es", "en"]

    /// Returns the more likely of the candidates, or nil when no probability is known.
    public static func pick(from probabilities: [String: Float]) -> String? {
        let scored = candidates.compactMap { code in probabilities[code].map { (code, $0) } }
        return scored.max { $0.1 < $1.1 }?.0
    }
}
