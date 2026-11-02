import Foundation

public enum Speaker: String, Codable, Sendable {
    case me
    case them
}

public struct TranscriptLine: Codable, Equatable, Sendable, Identifiable {
    public let speaker: Speaker
    /// Seconds from the start of the meeting.
    public let start: TimeInterval
    public let text: String

    public var id: String { "\(speaker.rawValue)-\(start)" }

    public init(speaker: Speaker, start: TimeInterval, text: String) {
        self.speaker = speaker
        self.start = start
        self.text = text
    }

    private enum CodingKeys: String, CodingKey { case speaker, start, text }
}

public struct Meeting: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let title: String
    /// Human name of the meeting app ("Zoom"), as shown in the note.
    public let app: String
    public let startedAt: Date
    public let endedAt: Date
    public let lines: [TranscriptLine]
    public let summary: String?

    public init(id: UUID = UUID(), title: String, app: String, startedAt: Date, endedAt: Date, lines: [TranscriptLine], summary: String? = nil) {
        self.id = id
        self.title = title
        self.app = app
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.lines = lines
        self.summary = summary
    }

    public var duration: TimeInterval { max(0, endedAt.timeIntervalSince(startedAt)) }

    public func withSummary(_ text: String?) -> Meeting {
        Meeting(id: id, title: title, app: app, startedAt: startedAt, endedAt: endedAt, lines: lines, summary: text)
    }

    public func appending(_ line: TranscriptLine) -> Meeting {
        Meeting(id: id, title: title, app: app, startedAt: startedAt, endedAt: endedAt, lines: lines + [line], summary: summary)
    }

    // MARK: Markdown

    public func markdown(timeZone: TimeZone = .current) -> String {
        var out = "---\n"
        out += "title: \(Meeting.quoted(title))\n"
        out += "app: \(Meeting.yamlScalar(app))\n"
        out += "date: \(Meeting.dateTime(startedAt, timeZone: timeZone))\n"
        out += "duration: \(Meeting.clock(duration))\n"
        out += "---\n\n"
        out += "# \(title)\n\n"
        for turn in Meeting.turns(lines) {
            let label = turn.speaker == .me ? "Yo" : "Ellos"
            out += "**\(label)** \(Meeting.clock(turn.start)) \(turn.text)\n\n"
        }
        if let summary, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            out += "## Resumen\n\n\(summary.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        }
        return out.hasSuffix("\n\n") ? String(out.dropLast()) : out
    }

    /// Lines ordered by time, with consecutive lines of the same speaker merged under the first one's time.
    static func turns(_ lines: [TranscriptLine]) -> [TranscriptLine] {
        let ordered = lines.enumerated()
            .sorted { $0.element.start != $1.element.start ? $0.element.start < $1.element.start : $0.offset < $1.offset }
            .map(\.element)
        return ordered.reduce(into: [TranscriptLine]()) { turns, line in
            let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            if let last = turns.last, last.speaker == line.speaker {
                turns[turns.count - 1] = TranscriptLine(speaker: last.speaker, start: last.start, text: last.text + " " + text)
            } else {
                turns.append(TranscriptLine(speaker: line.speaker, start: line.start, text: text))
            }
        }
    }

    /// `HH:MM:SS`.
    public static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    static func dateTime(_ date: Date, timeZone: TimeZone) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }

    static func quoted(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
        return "\"\(escaped)\""
    }

    static func yamlScalar(_ text: String) -> String {
        let plain = !text.isEmpty && text.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) || $0 == " " || $0 == "." || $0 == "-" }
        return plain ? text : quoted(text)
    }

    // MARK: Live file

    /// One JSON object on one line, without the trailing newline.
    public static func ndjsonLine(for line: TranscriptLine) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(line), let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    // MARK: Files

    public static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    public static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    /// `2026-11-02 Title`, safe as a file name on any volume.
    public func fileBase(timeZone: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "yyyy-MM-dd"
        let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|\n\r\t")
        let cleaned = title.unicodeScalars
            .map { forbidden.contains($0) ? " " : String($0) }
            .joined()
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
        let name = String(cleaned.prefix(80)).trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        return "\(f.string(from: startedAt)) \(name.isEmpty ? "Reunión" : name)"
    }
}
