import Foundation

/// How a dictation is added to a note: at the end, with one space between the old text and the new one.
public enum NoteInsertion {
    /// Returns the note with the dictation after its last character. The note itself is never changed
    /// in place, and an empty dictation gives the note back as it was.
    public static func appending(_ dictation: String, to note: String) -> String {
        let text = dictation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return note }
        guard let last = note.last else { return text }
        return last.isWhitespace ? note + text : note + " " + text
    }
}
