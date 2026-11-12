import Foundation

/// The names of the files the app and the keyboard share, all inside one folder.
public enum SharedFiles {
    public static let settings = "settings.json"
    public static let dictionary = "dictionary.json"
    public static let snippets = "snippets.json"
    public static let style = "style.json"
    public static let history = "history.json"
    public static let stats = "stats.json"
    /// The last result the keyboard inserted, so a keyboard created again does not insert it twice.
    public static let handledResult = "session-handled.json"
    public static let notesFolder = "Scratchpad"
}

/// Where the iPhone app and its keyboard keep everything: the App Group folder, or the app's own
/// folder when the group is not available (no entitlement, unit tests, the Mac).
public enum SharedContainer {
    public static func resolve(groupURL: URL?, fallback: URL) -> URL {
        groupURL ?? fallback
    }

    /// The one folder both sides use. The same call in the app and in the keyboard gives the same folder.
    public static var directory: URL {
        resolve(groupURL: groupURL, fallback: fallbackDirectory)
    }

    /// `true` when `directory` is the App Group folder, so the keyboard can see it.
    public static var isAppGroup: Bool { groupURL != nil }

    public static func file(_ name: String, in folder: URL = SharedContainer.directory) -> URL {
        folder.appendingPathComponent(name)
    }

    private static var groupURL: URL? {
        #if os(iOS)
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SessionChannel.appGroupID)
        #else
        return nil
        #endif
    }

    private static var fallbackDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Speak Away", isDirectory: true)
    }
}
