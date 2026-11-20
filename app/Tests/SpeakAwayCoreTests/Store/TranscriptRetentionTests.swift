import XCTest
@testable import SpeakAwayCore

final class TranscriptRetentionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 24 * 60 * 60

    func testMissingKeepTranscriptsKeyDecodesToFalse() throws {
        let settings = try JSONDecoder().decode(PhoneSettings.self, from: Data(#"{"language":"es"}"#.utf8))
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any]
        XCTAssertEqual(encoded?["keepTranscripts"] as? Bool, false)
    }

    func testFinishingDictationPurgesOldHistoryWithoutChangingEarlierStats() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let stores = SharedStores(folder: folder)
        try stores.recordDictation(text: "old words", raw: "old words", seconds: 4, at: now.addingTimeInterval(-11 * day))
        try stores.recordDictation(text: "new words", raw: "new words", seconds: 2, at: now)
        XCTAssertEqual(stores.history().map(\.text), ["new words"])
        XCTAssertEqual(stores.stats().totalWords, 4)
        XCTAssertEqual(stores.stats().totalSessions, 2)
        XCTAssertEqual(stores.stats().totalSeconds, 6)
    }

    func testRetentionUses240HoursAndLeavesInputsUntouched() {
        let dates: [TimeInterval] = [-9 * day, -10 * day + 3600, -10 * day, -10 * day - 1, 60]
        let items = dates.map { HistoryItem(date: now.addingTimeInterval($0), text: "words", raw: "words", app: nil) }
        let original = items
        let result = TranscriptRetention.partition(items, now: now, keepTranscripts: false, date: \.date)
        XCTAssertEqual(result.kept.map(\.id), [items[0].id, items[1].id, items[4].id])
        XCTAssertEqual(result.expired.map(\.id), [items[2].id, items[3].id])
        XCTAssertEqual(items, original)
    }

    func testKeepingTranscriptsPreservesEveryAge() {
        let items = [HistoryItem(date: now.addingTimeInterval(-100 * day), text: "old", raw: "old", app: nil)]
        let result = TranscriptRetention.partition(items, now: now, keepTranscripts: true, date: \.date)
        XCTAssertEqual(result.kept, items)
        XCTAssertTrue(result.expired.isEmpty)
    }

    func testPurgingIsIdempotentAndPreservesStatsAndOtherData() throws {
        try withStores { stores in
            try stores.recordDictation(text: "old words", raw: "old words", seconds: 4, at: now.addingTimeInterval(-11 * day))
            let savedStats = try Data(contentsOf: stores.folder.appendingPathComponent(SharedFiles.stats))
            let untouched = [SharedFiles.dictionary, SharedFiles.snippets, SharedFiles.style,
                             SharedFiles.notesFolder + "/note.txt"]
            for name in untouched {
                let file = stores.folder.appendingPathComponent(name)
                try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data("private note".utf8).write(to: file)
            }
            try stores.purgeTranscripts(now: now)
            try stores.purgeTranscripts(now: now)
            XCTAssertTrue(stores.history().isEmpty)
            XCTAssertEqual(try Data(contentsOf: stores.folder.appendingPathComponent(SharedFiles.stats)), savedStats)
            for name in untouched {
                XCTAssertEqual(try Data(contentsOf: stores.folder.appendingPathComponent(name)), Data("private note".utf8))
            }
        }
    }

    func testMeetingPurgeRemovesTranscriptSummaryJournalAudioAndChunksWithoutOrphans() throws {
        try withStores { stores in
            let meetings = NotesStore(folder: stores.folder.appendingPathComponent("Meetings"))
            let old = meeting(at: now.addingTimeInterval(-10 * day - 1))
            let recent = meeting(at: now.addingTimeInterval(-9 * day))
            let markdown = try meetings.save(old)
            let recentFile = try meetings.save(recent)
            let base = markdown.deletingPathExtension()
            for ext in ["wav", "m4a", "caf", "ndjson"] {
                try Data("private audio or transcript".utf8).write(to: base.appendingPathExtension(ext))
            }
            try Data("private audio".utf8).write(to: meetings.folder.appendingPathComponent(old.id.uuidString + ".wav"))
            let chunks = base.appendingPathExtension("chunks")
            try FileManager.default.createDirectory(at: chunks, withIntermediateDirectories: true)
            try Data("private audio".utf8).write(to: chunks.appendingPathComponent("001.caf"))
            let journal = meetings.folder.appendingPathComponent("live-old.ndjson")
            let header = MeetingJournal.Header(id: old.id, startedAt: old.startedAt, app: old.app, title: old.title)
            try Data((MeetingJournal.line(begin: header) + "\n").utf8).write(to: journal)
            try stores.purgeTranscripts(now: now)
            XCTAssertEqual(meetings.list(), [recent])
            XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: meetings.folder.path)),
                           Set([recentFile.lastPathComponent, recentFile.deletingPathExtension().appendingPathExtension("json").lastPathComponent]))
        }
    }

    func testPurgeRemovesExpiredJournalWithoutAFinishedMeeting() throws {
        try withStores { stores in
            let folder = stores.folder.appendingPathComponent("Meetings")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let old = meeting(at: now.addingTimeInterval(-10 * day))
            let header = MeetingJournal.Header(id: old.id, startedAt: old.startedAt, app: old.app, title: old.title)
            let file = folder.appendingPathComponent("live.ndjson")
            try Data((MeetingJournal.line(begin: header) + "\n").utf8).write(to: file)
            try stores.purgeTranscripts(now: now)
            XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        }
    }

    func testChangingRetentionAppliesImmediatelyAndKeepOnStopsPurging() throws {
        try withStores { stores in
            try stores.save(PhoneSettings(keepTranscripts: true), now: now)
            try stores.recordDictation(text: "old words", raw: "old words", seconds: 4, at: now.addingTimeInterval(-11 * day))
            try stores.purgeTranscripts(now: now)
            XCTAssertEqual(stores.history().count, 1)
            try stores.save(PhoneSettings(keepTranscripts: false), now: now)
            XCTAssertTrue(stores.history().isEmpty)
            XCTAssertEqual(stores.stats().totalWords, 2)
        }
    }

    func testConcurrentPurgeAndRecordingDoNotLoseRecentItemsOrStats() throws {
        try withStores { stores in
            try stores.recordDictation(text: "old words", raw: "old words", seconds: 1, at: now.addingTimeInterval(-11 * day))
            let workers = DispatchGroup()
            let queue = DispatchQueue(label: "retention-test", attributes: .concurrent)
            let errors = ErrorCollector()
            for index in 0..<20 {
                queue.async(group: workers) {
                    do {
                        let otherProcess = SharedStores(folder: stores.folder)
                        if index.isMultiple(of: 2) { try otherProcess.purgeTranscripts(now: self.now) }
                        else { try otherProcess.recordDictation(text: "new words", raw: "new words", seconds: 1, at: self.now) }
                    } catch { errors.append(error) }
                }
            }
            XCTAssertEqual(workers.wait(timeout: .now() + 10), .success)
            XCTAssertTrue(errors.values.isEmpty)
            XCTAssertEqual(stores.history().count, 10)
            XCTAssertEqual(stores.stats().totalSessions, 11)
        }
    }

    private func meeting(at date: Date) -> Meeting {
        Meeting(title: "Meeting", app: "Speak Away", startedAt: date, endedAt: date.addingTimeInterval(60),
                lines: [TranscriptLine(speaker: .room, start: 0, text: "private words")], summary: "private summary")
    }

    private func withStores(_ body: (SharedStores) throws -> Void) throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try body(SharedStores(folder: folder))
    }
}

private final class ErrorCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [Error] = []
    var values: [Error] { lock.lock(); defer { lock.unlock() }; return stored }
    func append(_ error: Error) { lock.lock(); defer { lock.unlock() }; stored = stored + [error] }
}
