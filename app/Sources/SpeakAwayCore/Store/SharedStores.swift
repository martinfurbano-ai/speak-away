import Foundation

/// Everything the iPhone app and its keyboard keep in the shared folder, loaded fresh on every call so
/// a change made by the other side is seen at once. These are the same stores the Mac uses
/// (`JSONFileStore`), only the folder differs.
public struct SharedStores {
    public let folder: URL

    public init(folder: URL = SharedContainer.directory) {
        self.folder = folder
    }

    private func store<Value: Codable>(_ name: String, as type: Value.Type = Value.self) -> JSONFileStore<Value> {
        JSONFileStore(url: SharedContainer.file(name, in: folder))
    }

    /// Coordinates journal file operations with retention in the app and keyboard processes.
    /// The closure must not call another locking SharedStores method.
    public func withTranscriptAccess<Value>(_ body: () throws -> Value) throws -> Value {
        try SharedFileLock.withLock(in: folder, body)
    }

    // MARK: Read

    public func settings() -> PhoneSettings { store(SharedFiles.settings).load(default: PhoneSettings()) }
    public func dictionary() -> PersonalDictionary { store(SharedFiles.dictionary).load(default: PersonalDictionary()) }
    public func snippets() -> Snippets { store(SharedFiles.snippets).load(default: Snippets()) }
    public func styles() -> StyleSettings { store(SharedFiles.style).load(default: StyleSettings()) }
    public func history() -> [HistoryItem] { store(SharedFiles.history).load(default: []) }
    public func stats() -> UsageStats { store(SharedFiles.stats).load(default: UsageStats()) }

    // MARK: Write

    public func save(_ settings: PhoneSettings, now: Date = Date()) throws {
        try SharedFileLock.withLock(in: folder) {
            try store(SharedFiles.settings).save(settings)
            try purgeUnlocked(now: now)
        }
    }

    /// Applies a change to the latest settings, without overwriting a concurrent change by the other process.
    @discardableResult
    public func updateSettings(now: Date = Date(), _ change: (inout PhoneSettings) -> Void) throws -> PhoneSettings {
        try SharedFileLock.withLock(in: folder) {
            let next = settings().changing(change)
            try store(SharedFiles.settings).save(next)
            try purgeUnlocked(now: now)
            return next
        }
    }
    public func save(_ dictionary: PersonalDictionary) throws { try store(SharedFiles.dictionary).save(dictionary) }
    public func save(_ snippets: Snippets) throws { try store(SharedFiles.snippets).save(snippets) }
    public func save(_ styles: StyleSettings) throws { try store(SharedFiles.style).save(styles) }
    /// The whole history, for example after one dictation was deleted.
    public func save(_ history: [HistoryItem]) throws {
        try SharedFileLock.withLock(in: folder) { try store(SharedFiles.history).save(history) }
    }

    public func deleteHistory(_ id: UUID) throws {
        try SharedFileLock.withLock(in: folder) {
            try store(SharedFiles.history).save(History.removing(id, from: history()))
        }
    }
    public func save(_ stats: UsageStats) throws {
        try SharedFileLock.withLock(in: folder) { try store(SharedFiles.stats).save(stats) }
    }

    /// Called at launch, foregrounding and session completion. The setting is read inside the same
    /// cross-process lock as deletion, so turning retention on stops subsequent purges immediately.
    public func purgeTranscripts(now: Date = Date()) throws {
        try SharedFileLock.withLock(in: folder) { try purgeUnlocked(now: now) }
    }

    @discardableResult
    public func saveMeeting(_ meeting: Meeting, now: Date = Date()) throws -> URL {
        try SharedFileLock.withLock(in: folder) {
            let url = try meetingStore.save(meeting)
            try purgeUnlocked(now: now)
            return url
        }
    }

    public func deleteMeeting(_ id: UUID) throws {
        try SharedFileLock.withLock(in: folder) { meetingStore.delete(id) }
    }

    private var meetingStore: NotesStore { NotesStore(folder: folder.appendingPathComponent("Meetings", isDirectory: true)) }

    private func purgeUnlocked(now: Date) throws {
        guard !settings().keepTranscripts else { return }
        let result = TranscriptRetention.partition(history(), now: now, keepTranscripts: false, date: \.date)
        if !result.expired.isEmpty { try store(SharedFiles.history).save(result.kept) }
        try MeetingRetentionFiles(folder: meetingStore.folder).purge(now: now)
    }

    /// Counts a finished dictation in the stats (numbers only) and, when the history is on, keeps its text.
    /// Returns the history item, or `nil` when the history is off or the text is empty.
    @discardableResult
    public func recordDictation(text: String, raw: String, seconds: Double, at date: Date = Date()) throws -> HistoryItem? {
        try SharedFileLock.withLock(in: folder) {
            try purgeUnlocked(now: date)
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            let stats = self.stats().recording(words: UsageStats.wordCount(text), seconds: seconds, on: DayKey(date))
            try store(SharedFiles.stats).save(stats)
            guard settings().historyEnabled else { return nil }
            let item = HistoryItem(date: date, text: text, raw: raw, app: nil)
            try store(SharedFiles.history).save(History.adding(item, to: history()))
            return item
        }
    }
}
