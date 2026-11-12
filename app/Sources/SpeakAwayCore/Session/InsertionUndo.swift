import Foundation

/// The last text the keyboard put into the document, and what to put back to undo it.
public struct LastInsertion: Equatable, Sendable {
    /// What is now in the document.
    public let inserted: String
    /// What stood there before (Command Mode); empty for a plain dictation.
    public let restoring: String

    public init(inserted: String, restoring: String = "") {
        self.inserted = inserted
        self.restoring = restoring
    }

    public static func dictation(_ text: String) -> LastInsertion {
        LastInsertion(inserted: text)
    }

    /// The result of Command Mode that replaced `target`.
    public static func command(replacing target: CommandTarget, with result: String) -> LastInsertion {
        LastInsertion(inserted: target.replacement(for: result), restoring: target.leading + target.text + target.trailing)
    }
}

/// What the keyboard does to undo: delete this many characters backward, then insert `insert`.
public struct UndoStep: Equatable, Sendable {
    public let deleteBackward: Int
    public let insert: String

    public init(deleteBackward: Int, insert: String) {
        self.deleteBackward = deleteBackward
        self.insert = insert
    }
}

public enum InsertionUndo {
    /// `nil` when there is nothing to undo or the document changed since the insertion: the text
    /// before the cursor must still end with what was inserted. Host apps may hand the keyboard only
    /// the last piece of a long paragraph, so a context that is the tail of the insertion also counts.
    public static func plan(for last: LastInsertion?, contextBeforeCursor: String?) -> UndoStep? {
        guard let last, !last.inserted.isEmpty, let context = contextBeforeCursor, !context.isEmpty else { return nil }
        guard context.hasSuffix(last.inserted) || last.inserted.hasSuffix(context) else { return nil }
        return UndoStep(deleteBackward: last.inserted.count, insert: last.restoring)
    }
}
