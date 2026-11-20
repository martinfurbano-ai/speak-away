import Foundation
import Speech
import SpeakAwayCore

/// Reads the confidence Apple actually provides. Missing confidence is never invented.
enum SpeechConfidence {
    static func candidate(text: AttributedString, locale: String) -> SpeechCandidate {
        let pieces = text.runs.map { run in
            SpeechCandidate(locale: locale, text: String(text[run.range].characters), confidence: run.transcriptionConfidence)
        }
        return SpeechCandidate(locale: locale, text: String(text.characters), confidence: average(pieces))
    }

    static func aggregate(_ pieces: [SpeechCandidate], locale: String) -> SpeechCandidate {
        SpeechCandidate(locale: locale, text: TranscriptJoiner.join(pieces.map(\.text)), confidence: average(pieces))
    }

    private static func average(_ pieces: [SpeechCandidate]) -> Double? {
        let scored = pieces.compactMap { piece -> (Double, Double)? in
            guard let value = piece.confidence, value.isFinite, (0...1).contains(value) else { return nil }
            let length = Double(piece.text.filter { $0.isLetter || $0.isNumber }.count)
            return length > 0 ? (value * length, length) : nil
        }
        let weight = scored.reduce(0) { $0 + $1.1 }
        guard weight > 0 else { return nil }
        return scored.reduce(0) { $0 + $1.0 } / weight
    }
}
