import Foundation

/// One on-device recognizer's hypothesis. Confidence is recognition confidence, not a language probability.
public struct SpeechCandidate: Equatable, Sendable {
    public let locale: String
    public let text: String
    public let confidence: Double?

    public init(locale: String, text: String, confidence: Double?) {
        self.locale = locale
        self.text = text
        self.confidence = confidence
    }
}

/// Chooses between complete hypotheses without changing them or combining different recognizers' words.
public enum SpeechSelection {
    public static func choose(_ candidates: [SpeechCandidate], preferredLocale: String) -> SpeechCandidate? {
        let preferred = SpeechLocale.languageCode(preferredLocale).lowercased()
        return candidates.filter { candidate in
            let cleaned = SpeechGate.clean(candidate.text)
            return cleaned.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) }
        }.sorted { left, right in
            let leftScore = score(left.confidence)
            let rightScore = score(right.confidence)
            if leftScore != rightScore { return leftScore > rightScore }
            let leftPreferred = SpeechLocale.languageCode(left.locale).lowercased() == preferred
            let rightPreferred = SpeechLocale.languageCode(right.locale).lowercased() == preferred
            if leftPreferred != rightPreferred { return leftPreferred }
            if left.locale != right.locale { return left.locale < right.locale }
            return left.text < right.text
        }.first
    }

    private static func score(_ confidence: Double?) -> Double {
        guard let confidence, confidence.isFinite, (0...1).contains(confidence) else { return -1 }
        return confidence
    }
}
