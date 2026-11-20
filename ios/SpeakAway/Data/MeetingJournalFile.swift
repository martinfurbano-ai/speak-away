import Foundation
import OSLog
import SpeakAwayCore

/// The file a meeting is written to while it is said (`MeetingJournal` in Core is its format). It is opened when the
/// meeting starts, checkpoints the selected language as sentences settle, and is removed once the note is saved.
/// If the app is killed or the phone restarts first, `leftovers` finds it and the words come back as a note.
final class MeetingJournalFile {
    /// What a journal left behind turns into.
    struct Leftover {
        let url: URL
        /// `nil`: nobody spoke, or the file has no start line. There is nothing to keep.
        let meeting: Meeting?
    }

    let url: URL
    private var handle: FileHandle?
    private let header: MeetingJournal.Header
    private let stores: SharedStores
    private static let logger = Logger(subsystem: "com.opensourceeverything.speakaway", category: "MeetingJournal")

    /// Opens a new journal in `folder` and writes the start line. A journal an earlier meeting left there is renamed
    /// first, so two meetings never share a file. `nil` if the file cannot be written: the meeting still records,
    /// it just has no crash protection.
    init?(folder: URL, header: MeetingJournal.Header, now: Date = Date()) {
        self.header = header
        stores = SharedStores(folder: folder.deletingLastPathComponent())
        let manager = FileManager.default
        let live = folder.appendingPathComponent(MeetingJournal.fileName)
        do {
            handle = try stores.withTranscriptAccess {
                try manager.createDirectory(at: folder, withIntermediateDirectories: true)
                if manager.fileExists(atPath: live.path) {
                    let stamp = String(Int(now.timeIntervalSince1970))
                    let name = "live-\(stamp)-\(UUID().uuidString.prefix(8)).ndjson"
                    try manager.moveItem(at: live, to: folder.appendingPathComponent(name))
                }
                try Data((MeetingJournal.line(begin: header) + "\n").utf8).write(to: live, options: .atomic)
                let opened = try FileHandle(forWritingTo: live)
                _ = try opened.seekToEnd()
                return opened
            }
            url = live
        } catch {
            Self.logger.error("Creating meeting journal failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// Atomically replaces the checkpoint when the winning language changes. A crash sees either complete version.
    func checkpoint(entries: [MeetingJournal.Entry], title: String) throws {
        let currentHeader = MeetingJournal.Header(id: header.id, startedAt: header.startedAt, app: header.app, title: title)
        let lines = [MeetingJournal.line(begin: currentHeader)] + entries.map(MeetingJournal.line(for:))
        try stores.withTranscriptAccess {
            guard try canWriteUnlocked() else { return }
            try Data((lines.joined(separator: "\n") + "\n").utf8).write(to: url, options: .atomic)
            try handle?.close()
            handle = nil
            let opened = try FileHandle(forWritingTo: url)
            _ = try opened.seekToEnd()
            handle = opened
        }
    }

    /// Adds a line and makes sure it reached the disk, so a crash right after loses nothing.
    func append(_ entry: MeetingJournal.Entry) {
        guard let handle else { return }
        do {
            try stores.withTranscriptAccess {
                guard try canWriteUnlocked() else { return }
                try handle.write(contentsOf: Data((MeetingJournal.line(for: entry) + "\n").utf8))
                try handle.synchronize()
            }
        } catch {
            Self.logger.error("Appending meeting journal failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// The meeting was saved (or there was nothing to save): the journal is not needed any more.
    func remove() {
        do {
            try stores.withTranscriptAccess {
                try handle?.close()
                handle = nil
                if try currentHeader()?.id == header.id { try FileManager.default.removeItem(at: url) }
            }
        } catch {
            Self.logger.error("Removing meeting journal failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Called only under the shared lock. Once a writer loses its journal it cannot recreate or overwrite one.
    private func canWriteUnlocked() throws -> Bool {
        guard handle != nil, let current = try currentHeader(), current.id == header.id else {
            try handle?.close()
            handle = nil
            return false
        }
        let retention = TranscriptRetention.partition([current], now: Date(), keepTranscripts: stores.settings().keepTranscripts,
                                                       date: \.startedAt)
        guard retention.expired.isEmpty else {
            try handle?.close()
            handle = nil
            try FileManager.default.removeItem(at: url)
            return false
        }
        return true
    }

    private func currentHeader() throws -> MeetingJournal.Header? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return MeetingJournal.header(from: try String(contentsOf: url, encoding: .utf8))
    }

    // MARK: Recovery

    /// The journals in `folder`, each with the meeting it holds. `english` only picks the words of the note that says
    /// the recording was cut off.
    static func leftovers(in folder: URL, english: Bool) -> [Leftover] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        let endNote = MeetingMarker.endedUnexpectedly.text(english: english)
        return names
            .filter { $0.hasPrefix("live") && $0.hasSuffix(".ndjson") }
            .sorted()
            .map { name in
                let url = folder.appendingPathComponent(name)
                let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                let touched = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
                return Leftover(url: url, meeting: MeetingJournal.recover(from: text, lastActivity: touched, endNote: endNote))
            }
    }
}
