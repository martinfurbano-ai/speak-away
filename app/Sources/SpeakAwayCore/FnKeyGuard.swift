import Foundation

/// Keeps the Fn (Globe) key for Speak Away alone.
///
/// macOS can bind that key to the emoji panel, the input source switcher or its own dictation. When it
/// does, a double tap opens the emoji panel, the panel takes the focus and the transcription is pasted
/// into its search field instead of the app. Two defenses, both decided here as pure values:
///
/// 1. The keyboard listener swallows the Fn key's own events (`swallows`), so no app ever sees a lone Fn.
/// 2. While Speak Away runs, the "Press Globe key to" setting is set to Do Nothing (`takeOver`), and the
///    person's own value comes back when the app quits (`restore`).
public enum FnKeyGuard {
    public enum EventKind: Sendable { case flagsChanged, keyDown, keyUp, other }

    /// macOS key codes: 63 is Fn as a modifier, 179 is the Globe key press on newer keyboards.
    public static let fnKeyCode: Int64 = 63
    public static let globeKeyCode: Int64 = 179

    /// The setting's domain and key, and its "Do Nothing" value (1 input source, 2 emoji, 3 dictation).
    public static let settingDomain = "com.apple.HIToolbox"
    public static let settingKey = "AppleFnUsageType"
    public static let doNothing = 0

    /// True for the events that are the Fn key itself. Fn plus another key (Fn + arrow, Fn + F1) arrives as
    /// that other key and keeps working.
    public static func swallows(_ kind: EventKind, keyCode: Int64) -> Bool {
        switch kind {
        case .flagsChanged: return keyCode == fnKeyCode
        case .keyDown, .keyUp: return keyCode == globeKeyCode
        case .other: return false
        }
    }

    /// What the setting held before Speak Away changed it.
    public enum Saved: Equatable, Sendable {
        /// Never set: macOS used its default.
        case absent
        case value(Int)

        /// Stored in Speak Away's own defaults as a number; -1 means "was absent".
        public var stored: Int {
            switch self {
            case .absent: return -1
            case .value(let v): return v
            }
        }

        public init?(stored: Int?) {
            guard let stored else { return nil }
            self = stored < 0 ? .absent : .value(stored)
        }
    }

    public struct TakeOver: Equatable, Sendable {
        public let write: Int
        public let remember: Saved
    }

    /// Given the setting's current value, what to write and what to remember. Nil when it already does nothing.
    public static func takeOver(current: Int?) -> TakeOver? {
        if current == doNothing { return nil }
        return TakeOver(write: doNothing, remember: current.map(Saved.value) ?? .absent)
    }

    public enum Restore: Equatable, Sendable {
        case write(Int)
        case remove
    }

    public static func restore(_ saved: Saved) -> Restore {
        switch saved {
        case .absent: return .remove
        case .value(let v): return .write(v)
        }
    }
}
