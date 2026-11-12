import Foundation

/// What the app writes to the shared container: the state, when it was written, and whether a result
/// answers Command Mode (so the keyboard replaces text instead of adding to it).
public struct SessionRecord: Codable, Equatable, Sendable {
    public let state: SessionState
    public let updatedAt: Date
    public let command: Bool

    public init(state: SessionState, updatedAt: Date, command: Bool = false) {
        self.state = state
        self.updatedAt = updatedAt
        self.command = command
    }

    private enum Key: String, CodingKey { case state, updatedAt, command }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        state = try c.decode(SessionState.self, forKey: .state)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        command = try c.decodeIfPresent(Bool.self, forKey: .command) ?? false
    }
}

/// Whether the app behind a published state is still there. The app re-publishes its state every
/// `heartbeatInterval`; a state nobody refreshed for `staleAfter` means the app was killed.
public enum SessionLiveness {
    public static let heartbeatInterval: TimeInterval = 4
    public static let staleAfter: TimeInterval = 12

    /// The state the keyboard should act on: `idle` when there is no record, it is stale, or the session ran out.
    public static func effectiveState(_ record: SessionRecord?, at now: Date) -> SessionState {
        guard let record, now.timeIntervalSince(record.updatedAt) <= staleAfter else { return .idle }
        return SessionPolicy.reconciled(record.state, at: now)
    }

    /// A session exists: the keyboard can talk to the app instead of opening it.
    public static func isLive(_ record: SessionRecord?, at now: Date) -> Bool {
        effectiveState(record, at: now) != .idle
    }
}

/// A dictation result the keyboard has not inserted yet.
public struct PendingResult: Equatable, Sendable {
    public let id: UUID
    public let text: String
    /// The result of Command Mode: it replaces the picked text.
    public let command: Bool
}

/// Makes sure each result is inserted once, even when the keyboard is created again and reads
/// the same `done` state a second time.
public struct ResultInbox: Equatable, Sendable {
    /// A result older than this is not inserted any more.
    public static let maxAge: TimeInterval = 30

    public let handled: UUID?

    public init(handled: UUID? = nil) {
        self.handled = handled
    }

    public func pending(in record: SessionRecord?, at now: Date) -> PendingResult? {
        guard let record, case .done(let id, let text) = record.state else { return nil }
        guard id != handled, !text.isEmpty, now.timeIntervalSince(record.updatedAt) <= Self.maxAge else { return nil }
        return PendingResult(id: id, text: text, command: record.command)
    }

    public func marking(_ id: UUID) -> ResultInbox {
        ResultInbox(handled: id)
    }
}
