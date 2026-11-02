import Foundation

/// A small local log of key events and dictation steps, to find out why a gesture did not work.
/// Lives in Application Support/Speak Away/debug.log, keeps the last 300 lines, never leaves the Mac.
enum DebugLog {
    private static let queue = DispatchQueue(label: "speakaway.debuglog")
    private static var lines: [String] = []

    static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Speak Away/debug.log")
    }

    static func write(_ message: String) {
        let stamp = String(format: "%.3f", ProcessInfo.processInfo.systemUptime)
        queue.async {
            lines.append("\(stamp) \(message)")
            if lines.count > 300 { lines.removeFirst(lines.count - 300) }
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
