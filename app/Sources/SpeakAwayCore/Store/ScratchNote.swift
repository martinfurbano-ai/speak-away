import Foundation

/// A note in the Scratchpad. Stored as one Markdown file with a small header.
public struct ScratchNote: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let created: Date
    public let updated: Date
    public let text: String

    public init(id: UUID = UUID(), created: Date = Date(), updated: Date? = nil, text: String) {
        self.id = id
        self.created = created
        self.updated = updated ?? created
        self.text = text
    }

    /// First non-empty line, at most 60 characters.
    public var title: String {
        let line = text.split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        return line.map { String($0.prefix(60)) } ?? "Nota vacía"
    }

    public func withText(_ newText: String, at date: Date = Date()) -> ScratchNote {
        ScratchNote(id: id, created: created, updated: date, text: newText)
    }

    private static func stamp(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }

    private static func date(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    public func markdown() -> String {
        "---\nid: \(id.uuidString)\ncreated: \(Self.stamp(created))\nupdated: \(Self.stamp(updated))\n---\n" + text
    }

    /// Reads a note file. A file without the header (written by hand) still loads when a fallback id is given.
    public static func parse(_ markdown: String, fallbackID: UUID? = nil, fallbackDate: Date? = nil) -> ScratchNote? {
        let lines = markdown.components(separatedBy: "\n")
        if lines.first == "---", let close = lines.dropFirst().firstIndex(of: "---") {
            var fields: [String: String] = [:]
            for line in lines[1..<close] {
                guard let colon = line.firstIndex(of: ":") else { continue }
                fields[String(line[..<colon])] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            }
            if let id = fields["id"].flatMap(UUID.init(uuidString:)) ?? fallbackID {
                let created = fields["created"].flatMap(date) ?? fallbackDate ?? Date()
                let updated = fields["updated"].flatMap(date) ?? created
                return ScratchNote(id: id, created: created, updated: updated, text: lines[(close + 1)...].joined(separator: "\n"))
            }
        }
        guard let id = fallbackID else { return nil }
        let d = fallbackDate ?? Date()
        return ScratchNote(id: id, created: d, updated: d, text: markdown)
    }
}

/// A folder with one `<id>.md` file per note.
public struct ScratchNotesFolder {
    public let directory: URL

    public init(directory: URL) { self.directory = directory }

    private func file(_ id: UUID) -> URL { directory.appendingPathComponent("\(id.uuidString).md") }

    /// Newest edit first. Files that are not notes are ignored.
    public func loadAll() -> [ScratchNote] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return urls.filter { $0.pathExtension == "md" }.compactMap { url in
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            return ScratchNote.parse(text, fallbackID: UUID(uuidString: url.deletingPathExtension().lastPathComponent) ?? UUID(), fallbackDate: modified)
        }.sorted { $0.updated > $1.updated }
    }

    public func save(_ note: ScratchNote) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try note.markdown().write(to: file(note.id), atomically: true, encoding: .utf8)
    }

    public func delete(_ id: UUID) {
        try? FileManager.default.removeItem(at: file(id))
    }
}
