import Foundation
import SpeakAwayCore

/// Exercises the real shared-folder deletion path in an isolated folder on the iPhone or simulator.
enum RetentionSelfTest {
    static func run(check: (String, Bool, String) -> Void) {
        let manager = FileManager.default
        let folder = SharedContainer.directory.appendingPathComponent("RetentionSelfTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? manager.removeItem(at: folder) }
        let stores = SharedStores(folder: folder)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let oldDate = now.addingTimeInterval(-(240 * 60 * 60) - 1)
        let recentDate = now.addingTimeInterval(-(239 * 60 * 60))
        let meetings = NotesStore(folder: folder.appendingPathComponent("Meetings", isDirectory: true))
        let old = Meeting(title: "Expired meeting", app: "Self test", startedAt: oldDate, endedAt: oldDate.addingTimeInterval(60),
                          lines: [TranscriptLine(speaker: .room, start: 0, text: "Old words")], summary: "Old summary")
        do {
            let decoded = try JSONDecoder().decode(PhoneSettings.self, from: Data("{}".utf8))
            check("a missing keepTranscripts key defaults to false", !decoded.keepTranscripts, "")
            try stores.save(PhoneSettings(keepTranscripts: true), now: now)
            try stores.recordDictation(text: "Old words", raw: "Old raw words", seconds: 12, at: oldDate)
            let recent = try stores.recordDictation(text: "Recent words", raw: "Recent raw words", seconds: 12, at: recentDate)
            let markdown = try stores.saveMeeting(old, now: now)
            let base = markdown.deletingPathExtension()
            let audio = base.appendingPathExtension("m4a")
            let chunks = base.appendingPathExtension("chunks")
            try Data("audio fixture".utf8).write(to: audio)
            try manager.createDirectory(at: chunks, withIntermediateDirectories: true)
            try Data("chunk fixture".utf8).write(to: chunks.appendingPathComponent("0001.wav"))
            let journal = meetings.folder.appendingPathComponent("live-retention-selftest.ndjson")
            let header = MeetingJournal.Header(id: old.id, startedAt: old.startedAt, app: old.app, title: old.title)
            try Data((MeetingJournal.line(begin: header) + "\n").utf8).write(to: journal)
            let stats = stores.stats()
            try stores.purgeTranscripts(now: now)
            check("keepTranscripts on keeps old history and meetings", stores.history().count == 2 && meetings.load(old.id) != nil, "")

            try stores.save(PhoneSettings(keepTranscripts: false), now: now)
            check("turning keepTranscripts off immediately removes expired history", stores.history().map(\.id) == [recent?.id].compactMap { $0 }, "")
            check("239-hour dictation stays", stores.history().first?.date == recentDate, "")
            let artifacts = [markdown, base.appendingPathExtension("json"), audio, chunks, journal]
            check("the expired meeting and every associated file are gone",
                  meetings.load(old.id) == nil && artifacts.allSatisfy { !manager.fileExists(atPath: $0.path) }, "")
            check("purging leaves usage statistics and streaks unchanged", stores.stats() == stats, "")
            let first = stores.history()
            try stores.purgeTranscripts(now: now)
            check("purging twice is idempotent", stores.history() == first && stores.stats() == stats, "")
            let leftovers = try manager.contentsOfDirectory(atPath: meetings.folder.path)
            check("no expired meeting file is orphaned", leftovers.isEmpty, leftovers.joined(separator: ", "))
        } catch {
            check("retention integration completed", false, String(describing: error))
        }
    }
}
