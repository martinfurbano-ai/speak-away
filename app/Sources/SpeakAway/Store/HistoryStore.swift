import Foundation
import SpeakAwayCore

/// The dictation history. Off means nothing is saved, not even in memory.
@MainActor
final class HistoryStore: ObservableObject {
    static let enabledKey = "historyEnabled"

    @Published private(set) var items: [HistoryItem]
    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.enabledKey) }
    }

    private let file: JSONFileStore<[HistoryItem]>
    private let defaults: UserDefaults

    /// `folder` is injectable for tests; `defaults` holds the on/off switch.
    init(folder: URL = StorePaths.directory, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        file = JSONFileStore(url: StorePaths.file(StorePaths.history, in: folder))
        items = file.load(default: [])
        isEnabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    /// Keeps a dictation. Returns it, or nil when the history is off or the text is empty.
    @discardableResult
    func add(text: String, raw: String, app: String?, date: Date = Date()) -> HistoryItem? {
        guard isEnabled, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let item = HistoryItem(date: date, text: text, raw: raw, app: app)
        items = History.adding(item, to: items)
        persist()
        return item
    }

    func delete(_ id: UUID) {
        items = History.removing(id, from: items)
        persist()
    }

    func clear() {
        items = []
        persist()
    }

    func search(_ query: String) -> [HistoryItem] {
        History.search(items, query)
    }

    private func persist() {
        try? file.save(items)
    }
}
