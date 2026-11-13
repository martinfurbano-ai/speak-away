import Foundation

/// One result of the speech engine, on the meeting's timeline.
public struct RecognizedPhrase: Equatable, Sendable {
    public let text: String
    /// Seconds from the start of the meeting.
    public let start: TimeInterval
    public let end: TimeInterval
    /// Final: the engine will not change it. Otherwise it is a guess that is replaced as more audio arrives.
    public let isFinal: Bool

    public init(text: String, start: TimeInterval, end: TimeInterval, isFinal: Bool) {
        self.text = text
        self.start = start
        self.end = end
        self.isFinal = isFinal
    }
}

/// The transcript as it grows. Final phrases are kept and joined into paragraphs; volatile text is only what is
/// on screen until the engine settles on it. Every change returns a new value.
public struct LiveTranscript: Equatable, Sendable {
    /// A silence longer than this starts a new paragraph.
    public static let paragraphGap: TimeInterval = 4
    /// A paragraph that would grow past this many characters starts a new one.
    public static let paragraphLimit = 420

    /// Paragraphs of the room and markers, in the order they happened.
    public let lines: [TranscriptLine]
    /// The engine's current guess for what is being said now. Never part of the saved transcript.
    public let volatile: String
    private let volatileStart: TimeInterval
    /// Where the last paragraph's speech ended.
    private let lastEnd: TimeInterval?

    public init(lines: [TranscriptLine] = [], volatile: String = "") {
        self.init(lines: lines, volatile: volatile, volatileStart: 0, lastEnd: nil)
    }

    private init(lines: [TranscriptLine], volatile: String, volatileStart: TimeInterval, lastEnd: TimeInterval?) {
        self.lines = lines
        self.volatile = volatile
        self.volatileStart = volatileStart
        self.lastEnd = lastEnd
    }

    /// Words said so far, markers left out.
    public var spokenWords: Int { MeetingTranscript.spokenWords(in: lines) }

    public func applying(_ phrase: RecognizedPhrase) -> LiveTranscript {
        let text = phrase.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard phrase.isFinal else {
            return LiveTranscript(lines: lines, volatile: text, volatileStart: phrase.start, lastEnd: lastEnd)
        }
        // A final result answers the guess that began before it ended. A guess that begins later is about newer audio.
        let keepsVolatile = !volatile.isEmpty && volatileStart >= phrase.end
        let nextVolatile = keepsVolatile ? volatile : ""
        guard !text.isEmpty else {
            return LiveTranscript(lines: lines, volatile: nextVolatile, volatileStart: volatileStart, lastEnd: lastEnd)
        }

        if let last = lines.last, last.speaker == .room, let lastEnd,
           phrase.start - lastEnd <= Self.paragraphGap,
           last.text.count + 1 + text.count <= Self.paragraphLimit {
            let joined = TranscriptLine(speaker: .room, start: last.start, text: last.text + " " + text)
            return LiveTranscript(lines: Array(lines.dropLast()) + [joined], volatile: nextVolatile,
                                  volatileStart: volatileStart, lastEnd: max(lastEnd, phrase.end))
        }
        let line = TranscriptLine(speaker: .room, start: phrase.start, text: text)
        return LiveTranscript(lines: lines + [line], volatile: nextVolatile, volatileStart: volatileStart, lastEnd: phrase.end)
    }

    /// The guess that never settled, as the final phrase it would have become, ending at `end`. The meeting is
    /// over (or the engine stopped), so the last words are kept instead of lost. `nil` when nothing is pending.
    public func unsettledPhrase(endingAt end: TimeInterval) -> RecognizedPhrase? {
        let guess = volatile.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !guess.isEmpty else { return nil }
        // A final result only answers a guess that began before it ended, so it always ends a little after it starts.
        return RecognizedPhrase(text: guess, start: volatileStart, end: max(end, volatileStart + 0.1), isFinal: true)
    }

    /// A note about the recording. It ends the paragraph before it, and drops a guess that will never settle.
    public func appendingMarker(_ text: String, at start: TimeInterval) -> LiveTranscript {
        LiveTranscript(lines: lines + [TranscriptLine(speaker: .marker, start: start, text: text)],
                       volatile: "", volatileStart: 0, lastEnd: nil)
    }
}
