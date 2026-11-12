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

    // MARK: Read

    public func settings() -> PhoneSettings { store(SharedFiles.settings).load(default: PhoneSettings()) }
    public func dictionary() -> PersonalDictionary { store(SharedFiles.dictionary).load(default: PersonalDictionary()) }
    public func snippets() -> Snippets { store(SharedFiles.snippets).load(default: Snippets()) }
    public func styles() -> StyleSettings { store(SharedFiles.style).load(default: StyleSettings()) }
    public func history() -> [HistoryItem] { store(SharedFiles.history).load(default: []) }
    public func stats() -> UsageStats { store(SharedFiles.stats).load(default: UsageStats()) }

    // MARK: Write

    public func save(_ settings: PhoneSettings) throws { try store(SharedFiles.settings).save(settings) }
    public func save(_ dictionary: PersonalDictionary) throws { try store(SharedFiles.dictionary).save(dictionary) }
    public func save(_ snippets: Snippets) throws { try store(SharedFiles.snippets).save(snippets) }
    public func save(_ styles: StyleSettings) throws { try store(SharedFiles.style).save(styles) }

    /// Counts a finished dictation in the stats (numbers only) and, when the history is on, keeps its text.
    /// Returns the history item, or `nil` when the history is off or the text is empty.
    @discardableResult
    public func recordDictation(text: String, raw: String, seconds: Double, at date: Date = Date()) throws -> HistoryItem? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let stats = self.stats().recording(words: UsageStats.wordCount(text), seconds: seconds, on: DayKey(date))
        try store(SharedFiles.stats).save(stats)
        guard settings().historyEnabled else { return nil }
        let item = HistoryItem(date: date, text: text, raw: raw, app: nil)
        try store(SharedFiles.history).save(History.adding(item, to: history()))
        return item
    }
}
