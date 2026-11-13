import Foundation
import SpeakAwayCore

/// What the screens show: the settings, history, numbers, dictionary, shortcuts, styles, notes and meetings kept in
/// the app's shared folder. Every change makes a new value, saves it, and publishes it; nothing is edited in place.
/// The keyboard writes to the same folder while the app is away, so `reload()` runs when the app comes back.
@MainActor
final class PhoneStore: ObservableObject {
    @Published private(set) var settings = PhoneSettings()
    @Published private(set) var history: [HistoryItem] = []
    @Published private(set) var stats = UsageStats()
    @Published private(set) var dictionary = PersonalDictionary()
    @Published private(set) var snippets = Snippets()
    @Published private(set) var styles = StyleSettings()
    @Published private(set) var notes: [ScratchNote] = []
    @Published private(set) var meetings: [Meeting] = []

    let folder: URL
    private let stores: SharedStores
    private let notesFolder: ScratchNotesFolder
    private let meetingStore: NotesStore

    init(folder: URL = SharedContainer.directory) {
        self.folder = folder
        self.stores = SharedStores(folder: folder)
        self.notesFolder = ScratchNotesFolder(directory: folder.appendingPathComponent(SharedFiles.notesFolder, isDirectory: true))
        self.meetingStore = NotesStore(folder: folder.appendingPathComponent("Meetings", isDirectory: true))
        recoverMeetings()
        reload()
    }

    /// Reads everything again from the folder.
    func reload() {
        settings = stores.settings()
        history = stores.history()
        stats = stores.stats()
        dictionary = stores.dictionary()
        snippets = stores.snippets()
        styles = stores.styles()
        notes = notesFolder.loadAll()
        meetings = meetingStore.list()
    }

    // MARK: Settings

    func updateSettings(_ change: (inout PhoneSettings) -> Void) {
        let next = settings.changing(change)
        guard next != settings else { return }
        try? stores.save(next)
        settings = next
    }

    // MARK: History

    func deleteHistory(_ id: UUID) {
        let next = History.removing(id, from: history)
        try? stores.save(next)
        history = next
    }

    // MARK: Voice

    func saveDictionary(_ next: PersonalDictionary) {
        try? stores.save(next)
        dictionary = next
    }

    func saveSnippets(_ next: Snippets) {
        try? stores.save(next)
        snippets = next
    }

    func setStyle(_ style: WritingStyle, for category: AppCategory) {
        let next = styles.setting(style, for: category)
        try? stores.save(next)
        styles = next
    }

    // MARK: Notes

    func note(_ id: UUID) -> ScratchNote? { notes.first { $0.id == id } }

    func meeting(_ id: UUID) -> Meeting? { meetings.first { $0.id == id } }

    /// An empty note, saved at once, newest on top.
    func newNote() -> ScratchNote {
        let created = ScratchNote(text: "")
        try? notesFolder.save(created)
        notes = [created] + notes
        return created
    }

    func updateNote(_ id: UUID, text: String) {
        guard let old = note(id), old.text != text else { return }
        let next = old.withText(text)
        try? notesFolder.save(next)
        notes = [next] + notes.filter { $0.id != id }
    }

    /// A dictation goes after the last word of the note.
    func appendToNote(_ id: UUID, dictation: String) {
        guard let old = note(id) else { return }
        updateNote(id, text: NoteInsertion.appending(dictation, to: old.text))
    }

    func deleteNote(_ id: UUID) {
        notesFolder.delete(id)
        notes = notes.filter { $0.id != id }
    }

    /// A note nobody wrote in is not kept.
    func discardNoteIfEmpty(_ id: UUID) {
        guard let current = note(id), current.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        deleteNote(id)
    }

    func deleteMeeting(_ id: UUID) {
        meetingStore.delete(id)
        meetings = meetings.filter { $0.id != id }
    }

    /// Saves a meeting (or its newer version, with a summary) and shows it at once. `false`: it could not be written.
    @discardableResult
    func saveMeeting(_ meeting: Meeting) -> Bool {
        do {
            try meetingStore.save(meeting)
        } catch {
            return false
        }
        meetings = ([meeting] + meetings.filter { $0.id != meeting.id }).sorted { $0.startedAt > $1.startedAt }
        return true
    }

    /// Where the meetings live, and where the journal of the meeting being recorded is written.
    var meetingsFolder: URL { meetingStore.folder }

    /// A meeting that was being recorded when the app was killed or the phone restarted left its journal behind:
    /// whatever was said comes back as a note. A journal that cannot be saved now stays for the next launch.
    private func recoverMeetings() {
        let known = Set(meetingStore.list().map(\.id))
        for leftover in MeetingJournalFile.leftovers(in: meetingStore.folder, english: !UILanguage.isSpanish) {
            if let meeting = leftover.meeting, !known.contains(meeting.id) {
                do { try meetingStore.save(meeting) } catch { continue }
            }
            try? FileManager.default.removeItem(at: leftover.url)
        }
    }
}
