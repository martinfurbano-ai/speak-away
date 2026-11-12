import Foundation

/// Puts the pieces the speech engine returns for one dictation back into a single text.
/// A long dictation comes back in several phrases; each is trimmed and joined with one space, and
/// closing punctuation sticks to the word before it, so words are never glued together or split from their comma.
public enum TranscriptJoiner {
    private static let attaching: Set<Character> = [".", ",", ";", ":", "!", "?", ")", "]", "}", "%", "”", "’", "»"]

    public static func join(_ pieces: [String]) -> String {
        var text = ""
        for piece in pieces {
            let trimmed = piece.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let first = trimmed.first else { continue }
            if text.isEmpty {
                text = trimmed
            } else if attaching.contains(first) {
                text += trimmed
            } else {
                text += " " + trimmed
            }
        }
        return text
    }
}
