import Foundation

/// The two lines a note shows in a list: its title (the first line with words in it) and a preview of what follows.
/// Unlike `ScratchNote.title`, an empty note has no title, so each screen words "empty note" in its own language.
public struct NoteOutline: Equatable, Sendable {
    public static let titleLimit = 60
    public static let previewLimit = 120

    /// `nil` when the note has no words.
    public let title: String?
    /// The rest of the note on one line, `nil` when there is nothing after the title.
    public let preview: String?

    public init(text: String) {
        let lines = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        title = lines.first.map { String($0.prefix(Self.titleLimit)) }
        let rest = lines.dropFirst().joined(separator: " ")
        preview = rest.isEmpty ? nil : String(rest.prefix(Self.previewLimit))
    }
}
