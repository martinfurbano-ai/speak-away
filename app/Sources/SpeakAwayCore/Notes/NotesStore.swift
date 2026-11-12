import Foundation

/// Meetings on disk: `<date> <title>.md` for people and `<date> <title>.json` next to it for the app.
/// Audio is never stored.
public struct NotesStore: Sendable {
    public let folder: URL
    let timeZone: TimeZone

    public static var defaultFolder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("Speak Away", isDirectory: true).appendingPathComponent("Meetings", isDirectory: true)
    }

    public init(folder: URL = NotesStore.defaultFolder, timeZone: TimeZone = .current) {
        self.folder = folder
        self.timeZone = timeZone
    }

    /// The transcript being written while a meeting is recorded, one JSON object per line.
    public var liveFile: URL { folder.appendingPathComponent("live.ndjson") }

    /// Writes the Markdown and the JSON; returns the Markdown URL.
    @discardableResult
    public func save(_ meeting: Meeting) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let previous = entry(for: meeting.id)
        let base = uniqueBase(meeting.fileBase(timeZone: timeZone), keeping: previous?.base)
        try Data(meeting.markdown(timeZone: timeZone).utf8).write(to: folder.appendingPathComponent(base + ".md"), options: .atomic)
        try Meeting.encoder.encode(meeting).write(to: folder.appendingPathComponent(base + ".json"), options: .atomic)
        if let previous, previous.base != base { remove(base: previous.base) }
        return folder.appendingPathComponent(base + ".md")
    }

    /// Newest first.
    public func list() -> [Meeting] {
        entries().map(\.meeting).sorted { $0.startedAt > $1.startedAt }
    }

    public func load(_ id: UUID) -> Meeting? { entry(for: id)?.meeting }

    public func delete(_ id: UUID) {
        if let found = entry(for: id) { remove(base: found.base) }
    }

    // MARK: Private

    private struct Entry {
        let base: String
        let meeting: Meeting
    }

    private func entries() -> [Entry] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.filter { $0.hasSuffix(".json") }.compactMap { name in
            guard
                let data = try? Data(contentsOf: folder.appendingPathComponent(name)),
                let meeting = try? Meeting.decoder.decode(Meeting.self, from: data)
            else { return nil }
            return Entry(base: String(name.dropLast(5)), meeting: meeting)
        }
    }

    private func entry(for id: UUID) -> Entry? { entries().first { $0.meeting.id == id } }

    private func uniqueBase(_ wanted: String, keeping own: String?) -> String {
        let fm = FileManager.default
        func free(_ base: String) -> Bool {
            base == own || !fm.fileExists(atPath: folder.appendingPathComponent(base + ".json").path)
        }
        if free(wanted) { return wanted }
        var n = 2
        while !free("\(wanted) \(n)") { n += 1 }
        return "\(wanted) \(n)"
    }

    private func remove(base: String) {
        for ext in ["md", "json"] { try? FileManager.default.removeItem(at: folder.appendingPathComponent(base + "." + ext)) }
    }
}
