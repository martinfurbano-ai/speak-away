import Foundation

/// Decides if a recording is worth sending to Whisper, and tidies what comes back.
/// Whisper invents text ("Thank you.", "Gracias por ver") on silence, so silence never reaches it.
public enum SpeechGate {
    public enum Verdict: Equatable, Sendable { case tooShort, silent, speech }

    public static let minSeconds = 0.3
    public static let silencePeak: Float = 0.015

    /// Speech is sustained energy, not one loud instant: a key click or the start chime over room
    /// noise has a high peak, and Whisper turns it into invented text. Quiet but steady speech counts.
    public static let windowSeconds = 0.03
    public static let voicedRMS: Float = 0.004
    public static let minVoicedSeconds = 0.3

    public static func check(_ audio: [Float], sampleRate: Int) -> Verdict {
        let duration = Double(audio.count) / Double(sampleRate)
        if duration < minSeconds { return .tooShort }
        return voicedSeconds(audio, sampleRate: sampleRate) >= minVoicedSeconds ? .speech : .silent
    }

    /// Total time in short windows louder than `voicedRMS`.
    public static func voicedSeconds(_ audio: [Float], sampleRate: Int) -> Double {
        let size = max(1, Int(Double(sampleRate) * windowSeconds))
        let voiced = stride(from: 0, to: audio.count - size + 1, by: size).filter { start in
            let energy = audio[start..<start + size].reduce(Float(0)) { $0 + $1 * $1 }
            return (energy / Float(size)).squareRoot() > voicedRMS * 1.001  // float rounding at the limit
        }
        return Double(voiced.count * size) / Double(sampleRate)
    }

    /// The same verdict from what was measured while recording, when the audio itself is not kept (iPhone).
    public static func check(duration: Double, peak: Float) -> Verdict {
        if duration < minSeconds { return .tooShort }
        return peak < silencePeak ? .silent : .speech
    }

    /// Trimmed text plus one trailing space, so the next dictation does not glue to it.
    /// Bracketed or parenthesised-only output ("[BLANK_AUDIO]", "(música)") is noise.
    public static func clean(_ raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return "" }
        let noise = (text.hasPrefix("[") && text.hasSuffix("]")) || (text.hasPrefix("(") && text.hasSuffix(")"))
        return noise ? "" : text + " "
    }
}
