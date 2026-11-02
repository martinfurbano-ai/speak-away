import Foundation
import SpeakAwayCore

/// The Scratchpad: quick notes, one Markdown file each, newest edit first.
@MainActor
final class ScratchpadStore: ObservableObject {
    @Published private(set) var notes: [ScratchNote]
    private let folder: ScratchNotesFolder

    init(folder: URL = StorePaths.file(StorePaths.notesFolder)) {
        self.folder = ScratchNotesFolder(directory: folder)
        notes = self.folder.loadAll()
    }

    @discardableResult
    func add(_ text: String, date: Date = Date()) -> ScratchNote {
        let note = ScratchNote(created: date, text: text)
        try? folder.save(note)
        notes = [note] + notes
        return note
    }

    func update(_ id: UUID, text: String, date: Date = Date()) {
        guard let old = notes.first(where: { $0.id == id }) else { return }
        let changed = old.withText(text, at: date)
        try? folder.save(changed)
        notes = [changed] + notes.filter { $0.id != id }
    }

    func delete(_ id: UUID) {
        folder.delete(id)
        notes = notes.filter { $0.id != id }
    }
}
