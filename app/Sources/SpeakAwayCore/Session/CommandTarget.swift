import Foundation

/// What Command Mode rewrites, and what the keyboard must do to replace it.
///
/// With a selection, that selection is the text and nothing is deleted, because `insertText`
/// replaces a selection. With no selection, it is the last sentence before the cursor, and the
/// keyboard deletes it backward before inserting the result.
public struct CommandTarget: Equatable, Sendable {
    /// The text to rewrite, without outer whitespace.
    public let text: String
    /// How many characters (as the user sees them) `deleteBackward()` must remove before inserting.
    public let deleteBackward: Int
    /// Whitespace that stood before the text. Put back around the result.
    public let leading: String
    /// Whitespace that stood after the text. Put back around the result.
    public let trailing: String

    public init(text: String, deleteBackward: Int, leading: String = "", trailing: String = "") {
        self.text = text
        self.deleteBackward = deleteBackward
        self.leading = leading
        self.trailing = trailing
    }

    /// The string for the keyboard to insert for the model's `result`.
    public func replacement(for result: String) -> String {
        leading + result.trimmingCharacters(in: .whitespacesAndNewlines) + trailing
    }

    /// `nil` when there is nothing to rewrite: no selection and no text before the cursor.
    /// A sentence ends at ".", "!", "?" or "…" followed by a space, or at a line break; a dot inside
    /// a number or an address does not end it, but an abbreviation like "Dr." does.
    public static func resolve(selectedText: String?, documentContextBeforeInput: String?) -> CommandTarget? {
        if let selected = selectedText, !selected.isEmpty {
            let (lead, core, trail) = TextEnvelope.split(selected)
            return core.isEmpty ? nil : CommandTarget(text: core, deleteBackward: 0, leading: lead, trailing: trail)
        }
        let context = documentContextBeforeInput ?? ""
        let (_, body, trail) = TextEnvelope.split(context)
        guard !body.isEmpty else { return nil }
        let sentence = String(body[lastSentenceStart(in: body)...])
        return CommandTarget(text: sentence, deleteBackward: sentence.count + trail.count, trailing: trail)
    }

    private static let terminators: Set<Character> = [".", "!", "?", "…"]
    private static let closers: Set<Character> = ["\"", "'", "”", "’", ")", "]", "»"]

    /// Where the last sentence of `body` (no outer whitespace) begins.
    private static func lastSentenceStart(in body: String) -> String.Index {
        var start = body.startIndex
        var i = body.startIndex
        while i < body.endIndex {
            let ch = body[i]
            if ch.isNewline {
                start = skippingWhitespace(in: body, from: body.index(after: i))
                i = start
            } else if terminators.contains(ch) {
                // Take the whole run: "...", "?!", and a closing quote after it.
                var end = body.index(after: i)
                while end < body.endIndex, terminators.contains(body[end]) || closers.contains(body[end]) {
                    end = body.index(after: end)
                }
                if end < body.endIndex, body[end].isWhitespace {
                    start = skippingWhitespace(in: body, from: end)
                    i = start
                } else {
                    i = end
                }
            } else {
                i = body.index(after: i)
            }
        }
        return start
    }

    private static func skippingWhitespace(in text: String, from index: String.Index) -> String.Index {
        var i = index
        while i < text.endIndex, text[i].isWhitespace { i = text.index(after: i) }
        return i
    }
}
