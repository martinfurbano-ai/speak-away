import Foundation

/// Decides if a recording is worth sending to Whisper, and tidies what comes back.
/// Whisper invents text ("Thank you.", "Gracias por ver") on silence, so silence never reaches it.
public enum SpeechGate {
    public enum Verdict: Equatable, Sendable { case tooShort, silent, speech }

    public static let minSeconds = 0.3
    public static let silencePeak: Float = 0.015

    public static func check(_ audio: [Float], sampleRate: Int) -> Verdict {
        if Double(audio.count) < Double(sampleRate) * minSeconds { return .tooShort }
        let peak = audio.reduce(Float(0)) { max($0, abs($1)) }
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
