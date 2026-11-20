import Foundation

/// Age is elapsed time, not calendar days, so daylight saving changes cannot alter the deadline.
public enum TranscriptRetention {
    public static let lifetime: TimeInterval = 240 * 60 * 60

    public struct Partition<Item> {
        public let kept: [Item]
        public let expired: [Item]
    }

    /// Keeps the input and its ordering intact. At exactly 240 hours the item expires.
    public static func partition<Item>(_ items: [Item], now: Date, keepTranscripts: Bool,
                                       date: (Item) -> Date) -> Partition<Item> {
        guard !keepTranscripts else { return Partition(kept: items, expired: []) }
        let cutoff = now.addingTimeInterval(-lifetime)
        return Partition(kept: items.filter { date($0) > cutoff },
                         expired: items.filter { date($0) <= cutoff })
    }
}
