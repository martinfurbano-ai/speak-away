import Foundation

/// Where Speak Away keeps its files: Application Support/Speak Away (inside the sandbox container when sandboxed).
enum StorePaths {
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Speak Away", isDirectory: true)
    }

    static func file(_ name: String, in folder: URL = StorePaths.directory) -> URL {
        folder.appendingPathComponent(name)
    }

    static let history = "history.json"
    static let dictionary = "dictionary.json"
    static let snippets = "snippets.json"
    static let style = "style.json"
    static let notesFolder = "Scratchpad"
}
