import Foundation

/// One dictation kept in the history.
public struct HistoryItem: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    /// What was pasted.
    public let text: String
    /// What the speech engine heard, before cleanup.
    public let raw: String
    /// The app it was pasted into, when known.
    public let app: String?
    public let words: Int

    public init(id: UUID = UUID(), date: Date = Date(), text: String, raw: String, app: String?, words: Int? = nil) {
        self.id = id
        self.date = date
        self.text = text
        self.raw = raw
        self.app = app
        self.words = words ?? UsageStats.wordCount(text)
    }
}

public enum History {
    public static let cap = 2_000

    /// Newest first, cut to `cap`.
    public static func adding(_ item: HistoryItem, to items: [HistoryItem], cap: Int = History.cap) -> [HistoryItem] {
        Array(([item] + items).prefix(max(0, cap)))
    }

    public static func removing(_ id: UUID, from items: [HistoryItem]) -> [HistoryItem] {
        items.filter { $0.id != id }
    }

    /// Every word of the query must appear in the text, the raw text or the app name,
    /// ignoring case and accents. An empty query matches everything.
    public static func search(_ items: [HistoryItem], _ query: String) -> [HistoryItem] {
        let terms = fold(query).split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !terms.isEmpty else { return items }
        return items.filter { item in
            let haystack = fold([item.text, item.raw, item.app ?? ""].joined(separator: "\n"))
            return terms.allSatisfy { haystack.contains($0) }
        }
    }

    private static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
