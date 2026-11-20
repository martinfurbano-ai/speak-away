import Foundation

/// One language's complete interpretation. Competing recognizers never append into each other's transcript.
/// Final phrases and the current guess are independent because the engines need not segment audio alike.
public struct MeetingSpeechSnapshot: Equatable, Sendable {
    public let locale: String
    public let phrases: [RecognizedPhrase]
    public let pending: RecognizedPhrase?
    private let confidences: [Double?]
    private let pendingConfidence: Double?

    public init(locale: String) {
        self.init(locale: locale, phrases: [], pending: nil, confidences: [], pendingConfidence: nil)
    }

    private init(locale: String, phrases: [RecognizedPhrase], pending: RecognizedPhrase?,
                 confidences: [Double?], pendingConfidence: Double?) {
        self.locale = locale
        self.phrases = phrases
        self.pending = pending
        self.confidences = confidences
        self.pendingConfidence = pendingConfidence
    }

    public func applying(_ phrase: RecognizedPhrase, confidence: Double?) -> MeetingSpeechSnapshot {
        guard phrase.isFinal else {
            return MeetingSpeechSnapshot(locale: locale, phrases: phrases, pending: phrase,
                                         confidences: confidences, pendingConfidence: confidence)
        }
        let keepsPending = pending.map { $0.start >= phrase.end } ?? false
        let hasText = !phrase.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return MeetingSpeechSnapshot(locale: locale, phrases: hasText ? phrases + [phrase] : phrases,
                                     pending: keepsPending ? pending : nil,
                                     confidences: hasText ? confidences + [confidence] : confidences,
                                     pendingConfidence: keepsPending ? pendingConfidence : nil)
    }

    public var candidate: SpeechCandidate {
        let allPhrases = phrases + (pending.map { [$0] } ?? [])
        let allConfidences = confidences + (pending == nil ? [] : [pendingConfidence])
        let weighted = zip(allPhrases, allConfidences).compactMap { phrase, confidence -> (Double, Double)? in
            guard let confidence, confidence.isFinite, (0...1).contains(confidence) else { return nil }
            let count = Double(phrase.text.count)
            return count > 0 ? (confidence * count, count) : nil
        }
        let weight = weighted.reduce(0) { $0 + $1.1 }
        let confidence = weight > 0 ? weighted.reduce(0) { $0 + $1.0 } / weight : nil
        return SpeechCandidate(locale: locale, text: TranscriptJoiner.join(allPhrases.map(\.text)), confidence: confidence)
    }

    /// Timeline events for the selected language, including recording markers in their original order.
    public func journalEntries(markers: [TranscriptLine] = []) -> [MeetingJournal.Entry] {
        let events: [(TimeInterval, MeetingJournal.Entry)] = markers.filter { $0.speaker == .marker }
            .map { ($0.start, .marker(start: $0.start, text: $0.text)) } + phrases.map { ($0.start, .phrase($0)) }
        return events.enumerated().sorted {
            $0.element.0 == $1.element.0 ? $0.offset < $1.offset : $0.element.0 < $1.element.0
        }.map { $0.element.1 }
    }

    public func transcript(markers: [TranscriptLine] = []) -> LiveTranscript {
        let settled = journalEntries(markers: markers).reduce(LiveTranscript()) { transcript, entry in
            switch entry {
            case .phrase(let phrase): return transcript.applying(phrase)
            case .marker(let start, let text): return transcript.appendingMarker(text, at: start)
            case .title: return transcript
            }
        }
        guard let pending, pending.end > (markers.map(\.start).max() ?? -.infinity) else { return settled }
        return settled.applying(pending)
    }

    /// Preserve the final guess when an engine ends without producing its settled form.
    public func settled(endingAt end: TimeInterval) -> MeetingSpeechSnapshot {
        guard let pending, !pending.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return self }
        return applying(RecognizedPhrase(text: pending.text, start: pending.start,
                                         end: max(end, pending.start + 0.1), isFinal: true), confidence: pendingConfidence)
    }
}
