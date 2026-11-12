import Foundation

/// The small JSON files the keyboard and the app pass to each other in the shared folder.
/// Writes are atomic, so a reader never sees half a file. A reader never moves or deletes a file:
/// it belongs to the other process.
public struct SessionFiles {
    public let folder: URL

    public init(folder: URL = SharedContainer.directory) {
        self.folder = folder
    }

    private func url(_ name: String) -> URL { SharedContainer.file(name, in: folder) }

    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    private func read<Value: Decodable>(_ name: String, as type: Value.Type = Value.self) -> Value? {
        guard let data = try? Data(contentsOf: url(name)) else { return nil }
        return try? decoder.decode(Value.self, from: data)
    }

    private func write<Value: Encodable>(_ value: Value, to name: String) {
        let target = url(name)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: target, options: .atomic)
    }

    // MARK: State (app to keyboard)

    public func readState() -> SessionRecord? { read(SessionChannel.stateFile) }

    public func write(state: SessionState, at date: Date, command: Bool = false) {
        write(SessionRecord(state: state, updatedAt: date, command: command), to: SessionChannel.stateFile)
    }

    // MARK: Request (keyboard to app)

    public func readRequest() -> SessionRequest? { read(SessionChannel.requestFile) }

    public func write(request: SessionRequest) { write(request, to: SessionChannel.requestFile) }

    // MARK: Handled result (keyboard)

    public func readHandledResult() -> UUID? { read(SharedFiles.handledResult) }

    public func markHandled(_ id: UUID) { write(id, to: SharedFiles.handledResult) }

    public func inbox() -> ResultInbox { ResultInbox(handled: readHandledResult()) }
}

/// The keyboard's end of the conversation with the app (the self test plays the keyboard with it too):
/// read the published state, send requests, take each result once, and hear when the app writes.
public final class SessionClient {
    private let files: SessionFiles
    private let now: () -> Date
    private var observer: DarwinObserver?

    public init(files: SessionFiles = SessionFiles(), now: @escaping () -> Date = Date.init) {
        self.files = files
        self.now = now
    }

    public var record: SessionRecord? { files.readState() }

    /// The state to act on: `idle` when there is no session or the app stopped refreshing it.
    public var state: SessionState { SessionLiveness.effectiveState(record, at: now()) }

    public var isLive: Bool { SessionLiveness.isLive(record, at: now()) }

    /// Writes the request and wakes the app.
    @discardableResult
    public func send(_ message: SessionMessage, field: FieldContext) -> SessionRequest {
        let request = SessionRequest(sentAt: now(), message: message, field: field)
        files.write(request: request)
        DarwinNotifier.post(SessionChannel.requestNotification)
        return request
    }

    /// The result to insert, once. A second call, or another keyboard instance, gets `nil` for it.
    public func takePendingResult() -> PendingResult? {
        guard let pending = files.inbox().pending(in: files.readState(), at: now()) else { return nil }
        files.markHandled(pending.id)
        return pending
    }

    /// Calls `handler` on the main queue whenever the app publishes a state.
    public func observe(_ handler: @escaping () -> Void) {
        observer = DarwinObserver(name: SessionChannel.stateNotification, handler: handler)
    }

    public func stopObserving() {
        observer?.stop()
        observer = nil
    }
}
