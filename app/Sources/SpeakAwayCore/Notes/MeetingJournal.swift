import Foundation

/// The file a meeting is written to while it is said, one JSON object per line, appended and never rewritten.
/// If the app is killed or the phone restarts, `recover` rebuilds the meeting from what is in it, so nothing
/// that was said is lost. The Mac's `live.ndjson` plays the same part.
public enum MeetingJournal {
    /// `NotesStore` lists `.json` files only, so the journal never shows up as a finished meeting.
    public static let fileName = "live.ndjson"

    public struct Header: Equatable, Sendable {
        public let id: UUID
        public let startedAt: Date
        public let app: String
        public let title: String

        public init(id: UUID, startedAt: Date, app: String, title: String) {
            self.id = id
            self.startedAt = startedAt
            self.app = app
            self.title = title
        }
    }

    public enum Entry: Equatable, Sendable {
        /// A final phrase from the speech engine.
        case phrase(RecognizedPhrase)
        case marker(start: TimeInterval, text: String)
        /// The user typed a new title.
        case title(String)
    }

    // MARK: Writing

    /// The first line of the file, without the trailing newline.
    public static func line(begin header: Header) -> String {
        encode(Record(kind: .begin, id: header.id, startedAt: header.startedAt, app: header.app, title: header.title))
    }

    public static func line(for entry: Entry) -> String {
        switch entry {
        case .phrase(let phrase): return encode(Record(kind: .phrase, text: phrase.text, start: phrase.start, end: phrase.end))
        case .marker(let start, let text): return encode(Record(kind: .marker, text: text, start: start))
        case .title(let title): return encode(Record(kind: .title, text: title))
        }
    }

    // MARK: Recovering

    /// The meeting the journal holds, or `nil` when it has no header or nobody spoke. A last line cut off by the
    /// crash is skipped. `lastActivity` is the last time the file was written, and the meeting ends there (or at its
    /// last words, if later); `endNote` is the marker that says it was cut off (empty: none).
    public static func recover(from text: String, lastActivity: Date, endNote: String) -> Meeting? {
        var header: Header?
        var title: String?
        var transcript = LiveTranscript()
        var lastSecond: TimeInterval = 0

        for raw in text.split(whereSeparator: \.isNewline) {
            guard let record = decode(String(raw)) else { continue }
            switch record.kind {
            case .begin:
                if header == nil, let id = record.id, let startedAt = record.startedAt {
                    header = Header(id: id, startedAt: startedAt, app: record.app ?? "", title: record.title ?? "")
                }
            case .title:
                title = record.text
            case .phrase:
                let start = record.start ?? 0
                let end = record.end ?? start
                transcript = transcript.applying(RecognizedPhrase(text: record.text ?? "", start: start, end: end, isFinal: true))
                lastSecond = max(lastSecond, end)
            case .marker:
                let start = record.start ?? 0
                transcript = transcript.appendingMarker(record.text ?? "", at: start)
                lastSecond = max(lastSecond, start)
            }
        }

        guard let header, transcript.lines.contains(where: { $0.speaker == .room }) else { return nil }
        let endOffset = max(lastSecond, lastActivity.timeIntervalSince(header.startedAt))
        let closed = endNote.isEmpty ? transcript : transcript.appendingMarker(endNote, at: endOffset)
        return Meeting(id: header.id, title: title ?? header.title, app: header.app, startedAt: header.startedAt,
                       endedAt: header.startedAt.addingTimeInterval(endOffset), lines: closed.lines)
    }

    // MARK: One line of the file

    private struct Record: Codable {
        enum Kind: String, Codable { case begin, phrase, marker, title }
        let kind: Kind
        var id: UUID?
        var startedAt: Date?
        var app: String?
        var title: String?
        var text: String?
        var start: TimeInterval?
        var end: TimeInterval?
    }

    private static func encode(_ record: Record) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(record), let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    private static func decode(_ line: String) -> Record? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Record.self, from: Data(line.utf8))
    }
}
