import Foundation

/// A meeting's lines as the text the on-device model reads.
public enum MeetingTranscript {
    /// Fewer words than this are not worth summarizing: the model would invent what is not there.
    public static let minimumWords = 15

    /// One turn per line, ordered by time. A call keeps the Mac's labels ("Yo", "Ellos"); a room has none.
    /// Markers are notes about the recording, not part of the meeting, so they are left out.
    public static func text(for lines: [TranscriptLine]) -> String {
        Meeting.turns(lines).compactMap { turn -> String? in
            switch turn.speaker {
            case .me: return "Yo: \(turn.text)"
            case .them: return "Ellos: \(turn.text)"
            case .room: return turn.text
            case .marker: return nil
            }
        }.joined(separator: "\n")
    }

    /// Words that were said, markers left out.
    public static func spokenWords(in lines: [TranscriptLine]) -> Int {
        lines.filter { $0.speaker != .marker }
            .reduce(0) { $0 + $1.text.split(whereSeparator: \.isWhitespace).count }
    }

    public static func hasEnoughToSummarize(_ lines: [TranscriptLine]) -> Bool {
        spokenWords(in: lines) >= minimumWords
    }
}

/// What to do about the summary when a meeting stops. The transcript is saved first and is never lost,
/// whatever the plan says.
public enum SummaryPlan: Equatable, Sendable {
    /// Too little was said.
    case nothingToSummarize
    /// The brain is on and available: summarize now.
    case summarizeNow
    /// The brain is switched off in the app: keep the transcript.
    case brainOff
    /// Apple Intelligence is on but its model is still being prepared: the detail screen offers to try again.
    case leaveForLater
    /// This iPhone cannot summarize: the system is too old, the device is not eligible, or Apple Intelligence is off.
    case needsAppleIntelligence

    /// Only this plan runs the model on stop.
    public var runsOnStop: Bool { self == .summarizeNow }

    public static func decide(lines: [TranscriptLine], brainOn: Bool, availability: BrainAvailability) -> SummaryPlan {
        guard MeetingTranscript.hasEnoughToSummarize(lines) else { return .nothingToSummarize }
        switch availability {
        case .needsAppleIntelligence, .unsupportedOS, .deviceNotEligible: return .needsAppleIntelligence
        case .available, .modelNotReady:
            guard brainOn else { return .brainOff }
            return availability == .available ? .summarizeNow : .leaveForLater
        }
    }
}
