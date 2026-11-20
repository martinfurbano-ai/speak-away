import Foundation

/// Removes the complete file family of an expired meeting. iPhone audio is currently memory only;
/// basename and ID companions, including directories, are removed if present.
struct MeetingRetentionFiles {
    let folder: URL

    private struct Metadata: Decodable {
        let id: UUID
        let startedAt: Date
    }

    private struct Entry {
        let base: String
        let meeting: Metadata
    }

    func purge(now: Date) throws {
        guard FileManager.default.fileExists(atPath: folder.path) else { return }
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        let entries = files.filter { $0.pathExtension == "json" }.compactMap { file -> Entry? in
            guard let data = try? Data(contentsOf: file),
                  let meeting = try? Meeting.decoder.decode(Metadata.self, from: data) else { return nil }
            return Entry(base: file.deletingPathExtension().lastPathComponent, meeting: meeting)
        }.sorted { $0.base.count > $1.base.count }
        let expired = TranscriptRetention.partition(entries, now: now, keepTranscripts: false,
                                                    date: { $0.meeting.startedAt }).expired
        let expiredIDs = Set(expired.map { $0.meeting.id })
        let journals = try files.filter { $0.pathExtension == "ndjson" }.filter { file in
            guard let header = try journalHeader(at: file) else { return false }
            return expiredIDs.contains(header.id)
                || !TranscriptRetention.partition([header], now: now, keepTranscripts: false, date: \.startedAt).expired.isEmpty
        }
        // Keep the JSON index until companions are gone. If deletion fails, the next purge can retry.
        for journal in journals { try removeIfPresent(journal) }
        for entry in expired {
            let companions = files.filter { file in
                guard file.lastPathComponent != entry.base + ".json" else { return false }
                let identifier = entry.meeting.id.uuidString
                if file.lastPathComponent == identifier || file.lastPathComponent.hasPrefix(identifier + ".") { return true }
                let owner = entries.first { file.lastPathComponent.hasPrefix($0.base + ".") }
                return owner?.meeting.id == entry.meeting.id
            }
            for file in companions { try removeIfPresent(file) }
            try removeIfPresent(folder.appendingPathComponent(entry.base + ".json"))
        }
    }

    private func journalHeader(at url: URL) throws -> MeetingJournal.Header? {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let data = try file.read(upToCount: 64 * 1024) ?? Data()
        return MeetingJournal.header(from: String(decoding: data, as: UTF8.self))
    }

    private func removeIfPresent(_ url: URL) throws {
        do { try FileManager.default.removeItem(at: url) }
        catch CocoaError.fileNoSuchFile { }
    }
}
