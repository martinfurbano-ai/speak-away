import Foundation

/// What the keyboard asks the app to do. Written by the keyboard, read by the app.
public enum SessionMessage: Equatable, Sendable {
    /// Start recording the dictation.
    case start
    /// Stop recording and transcribe.
    case stop
    /// Drop the recording without transcribing.
    case cancel
    /// Command Mode, spoken: start recording an instruction for `on`, the text the keyboard picked
    /// (`CommandTarget.text`). `stop` ends it; the result replaces that text.
    case startCommand(on: String)
    /// Command Mode, already written: apply `instruction` to `on` right away, without recording.
    case command(instruction: String, on: String)
}

extension SessionMessage: Codable {
    private enum Kind: String, Codable { case start, stop, cancel, startCommand, command }
    private enum Key: String, CodingKey { case type, instruction, text }

    // Stored as {"type": "command", "instruction": "...", "text": "..."}: readable, and stable if cases are added.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        switch try c.decode(Kind.self, forKey: .type) {
        case .start: self = .start
        case .stop: self = .stop
        case .cancel: self = .cancel
        case .startCommand: self = .startCommand(on: try c.decode(String.self, forKey: .text))
        case .command:
            self = .command(instruction: try c.decode(String.self, forKey: .instruction),
                            on: try c.decode(String.self, forKey: .text))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Key.self)
        switch self {
        case .start: try c.encode(Kind.start, forKey: .type)
        case .stop: try c.encode(Kind.stop, forKey: .type)
        case .cancel: try c.encode(Kind.cancel, forKey: .type)
        case .startCommand(let text):
            try c.encode(Kind.startCommand, forKey: .type)
            try c.encode(text, forKey: .text)
        case .command(let instruction, let text):
            try c.encode(Kind.command, forKey: .type)
            try c.encode(instruction, forKey: .instruction)
            try c.encode(text, forKey: .text)
        }
    }
}

/// The file the keyboard writes: a message with an id, so the app can ignore one it already handled.
/// It also says what kind of field the keyboard is in and which style the user picked for it.
public struct SessionRequest: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let sentAt: Date
    public let message: SessionMessage
    public let field: FieldContext

    public init(id: UUID = UUID(), sentAt: Date = Date(), message: SessionMessage, field: FieldContext = .general) {
        self.id = id
        self.sentAt = sentAt
        self.message = message
        self.field = field
    }

    /// The request a keyboard builds from the traits of the field it is typing into.
    /// `keyboardType` and `contentType` are `UIKeyboardType.rawValue` and `UITextContentType.rawValue`.
    public static func make(_ message: SessionMessage, keyboardType: Int, contentType: String?,
                            styleOverride: WritingStyle? = nil, id: UUID = UUID(), sentAt: Date = Date()) -> SessionRequest {
        SessionRequest(id: id, sentAt: sentAt, message: message,
                       field: FieldContext(keyboardType: keyboardType, contentType: contentType, styleOverride: styleOverride))
    }

    private enum Key: String, CodingKey { case id, sentAt, message, field }

    // A file written before `field` existed still decodes: it reads as a general field.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        id = try c.decode(UUID.self, forKey: .id)
        sentAt = try c.decode(Date.self, forKey: .sentAt)
        message = try c.decode(SessionMessage.self, forKey: .message)
        field = try c.decodeIfPresent(FieldContext.self, forKey: .field) ?? .general
    }
}

/// What the app tells the keyboard. Written by the app, read by the keyboard.
public enum SessionState: Equatable, Sendable {
    /// No session: the keyboard has to open the app to start one.
    case idle
    /// The mic is ready in the background until that date (`nil`: until the user stops it).
    case ready(until: Date?)
    /// Recording right now; `level` is the voice loudness for the level bars.
    case recording(level: Double)
    case transcribing
    /// The text to insert. `id` lets the keyboard insert each result once.
    case done(id: UUID, text: String)
    case failed(reason: String)

    /// Loudness clamped to 0...1 (0 when not recording).
    public var level: Double {
        guard case .recording(let level) = self else { return 0 }
        return min(1, max(0, level))
    }

    /// The keyboard can record in this state.
    public var canRecord: Bool {
        if case .ready = self { return true }
        return false
    }
}

extension SessionState: Codable {
    private enum Kind: String, Codable { case idle, ready, recording, transcribing, done, failed }
    private enum Key: String, CodingKey { case type, until, level, id, text, reason }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        switch try c.decode(Kind.self, forKey: .type) {
        case .idle: self = .idle
        case .ready: self = .ready(until: try c.decodeIfPresent(Date.self, forKey: .until))
        case .recording: self = .recording(level: try c.decode(Double.self, forKey: .level))
        case .transcribing: self = .transcribing
        case .done: self = .done(id: try c.decode(UUID.self, forKey: .id), text: try c.decode(String.self, forKey: .text))
        case .failed: self = .failed(reason: try c.decode(String.self, forKey: .reason))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Key.self)
        switch self {
        case .idle: try c.encode(Kind.idle, forKey: .type)
        case .ready(let until):
            try c.encode(Kind.ready, forKey: .type)
            try c.encodeIfPresent(until, forKey: .until)
        case .recording(let level):
            try c.encode(Kind.recording, forKey: .type)
            try c.encode(level, forKey: .level)
        case .transcribing: try c.encode(Kind.transcribing, forKey: .type)
        case .done(let id, let text):
            try c.encode(Kind.done, forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(text, forKey: .text)
        case .failed(let reason):
            try c.encode(Kind.failed, forKey: .type)
            try c.encode(reason, forKey: .reason)
        }
    }
}

/// Names both sides must agree on: the App Group, the files in its container, the Darwin
/// notifications that wake the other side, and the URL that opens the app to start a session.
public enum SessionChannel {
    public static let appGroupID = "group.com.opensourceeverything.speakaway"
    public static let urlScheme = "speakaway"

    /// Keyboard to app.
    public static let requestFile = "session-request.json"
    /// App to keyboard.
    public static let stateFile = "session-state.json"

    public static let requestNotification = "com.opensourceeverything.speakaway.session.request"
    public static let stateNotification = "com.opensourceeverything.speakaway.session.state"

    /// Opened by the keyboard when no session is running.
    public static let startURL = URL(string: "\(urlScheme)://session/start")!
    /// Opened by the keyboard when it needs Full Access or the keyboard is not set up yet.
    public static let setupURL = URL(string: "\(urlScheme)://setup")!
}
