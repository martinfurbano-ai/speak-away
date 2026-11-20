import Foundation
import SpeakAwayCore

/// An in-flight writer must not bring back a journal that another process has purged.
enum JournalRetentionSelfTest {
    static func run(check: (String, Bool, String) -> Void) {
        let manager = FileManager.default
        let folder = manager.temporaryDirectory.appendingPathComponent("JournalRetention-\(UUID().uuidString)", isDirectory: true)
        defer { try? manager.removeItem(at: folder) }
        let stores = SharedStores(folder: folder)
        let now = Date()
        let old = now.addingTimeInterval(-TranscriptRetention.lifetime - 1)
        let meetings = folder.appendingPathComponent("Meetings", isDirectory: true)
        let header = MeetingJournal.Header(id: UUID(), startedAt: old, app: "Self test", title: "Old")
        let entry = MeetingJournal.Entry.phrase(RecognizedPhrase(text: "Old words", start: 0, end: 1, isFinal: true))
        do {
            try stores.save(PhoneSettings(keepTranscripts: true), now: now)
            guard let journal = MeetingJournalFile(folder: meetings, header: header, now: now) else {
                check("journal retention fixture opens", false, "")
                return
            }
            journal.append(entry)
            try stores.save(PhoneSettings(keepTranscripts: false), now: now)
            check("purge deletes a journal with an open writer", !manager.fileExists(atPath: journal.url.path), "")
            try journal.checkpoint(entries: [entry], title: "Late checkpoint")
            check("a late checkpoint cannot recreate a purged journal", !manager.fileExists(atPath: journal.url.path), "")
            try stores.save(PhoneSettings(keepTranscripts: true), now: now)
            try journal.checkpoint(entries: [entry], title: "Still deleted")
            journal.append(entry)
            check("enabling retention cannot resurrect a purged journal", !manager.fileExists(atPath: journal.url.path), "")
            let replacementHeader = MeetingJournal.Header(id: UUID(), startedAt: now, app: "Self test", title: "New")
            guard let replacement = MeetingJournalFile(folder: meetings, header: replacementHeader, now: now) else {
                check("replacement journal opens", false, "")
                return
            }
            try journal.checkpoint(entries: [entry], title: "Stale writer")
            journal.remove()
            let saved = try String(contentsOf: replacement.url, encoding: .utf8)
            check("a stale writer cannot overwrite or remove a replacement journal",
                  MeetingJournal.header(from: saved)?.id == replacementHeader.id && !saved.contains("Old words"), "")
            replacement.remove()
        } catch {
            check("journal retention integration completed", false, String(describing: error))
        }
    }
}
