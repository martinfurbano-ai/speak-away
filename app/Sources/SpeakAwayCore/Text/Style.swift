import Foundation

/// How formal the dictated text should read.
public enum WritingStyle: String, Codable, CaseIterable, Sendable {
    /// The text as it is, with final punctuation.
    case formal
    /// A short single sentence loses its final period; "?" and "!" stay.
    case casual
    /// Like casual, plus a lowercase first letter. The final period goes in any text, long or not.
    case veryCasual
}

public enum Style {
    /// "Short" for casual: up to this many words.
    public static let shortSentenceWords = 12

    public static func apply(_ text: String, style: WritingStyle) -> String {
        let (lead, core, trail) = TextEnvelope.split(text)
        if core.isEmpty { return text }
        let styled: String
        switch style {
        case .formal:
            styled = withFinalPunctuation(core)
        case .casual:
            styled = isShortSingleSentence(core) ? droppingFinalPeriod(core) : core
        case .veryCasual:
            styled = lowercasingFirstLetter(droppingFinalPeriod(core))
        }
        return lead + styled + trail
    }

    private static func withFinalPunctuation(_ text: String) -> String {
        guard let last = text.last else { return text }
        if last == "," || last == ";" { return String(text.dropLast()) + "." }
        return last.isLetter || last.isNumber ? text + "." : text
    }

    /// One "." at the end goes; "..." (a trailing pause) stays.
    private static func droppingFinalPeriod(_ text: String) -> String {
        guard text.hasSuffix("."), !text.hasSuffix("..") else { return text }
        return String(text.dropLast())
    }

    private static func isShortSingleSentence(_ text: String) -> Bool {
        let words = text.split(whereSeparator: { $0.isWhitespace }).count
        let body = text.hasSuffix(".") ? String(text.dropLast()) : text
        return words <= shortSentenceWords && !Rx.matches(body, "[.!?…]+(?:\\s|$)")
    }

    /// Lowercases the first letter of the first word, unless it is "I", an acronym or a name with inner capitals.
    private static func lowercasingFirstLetter(_ text: String) -> String {
        guard let start = text.firstIndex(where: { $0.isLetter }) else { return text }
        let word = text[start...].prefix(while: { $0.isLetter || $0 == "'" || $0 == "’" || $0 == "-" })
        guard let first = word.first, first.isUppercase else { return text }
        if word == "I" || word.hasPrefix("I'") || word.hasPrefix("I’") { return text }
        if word.dropFirst().contains(where: { $0.isUppercase }) { return text }
        return String(text[..<start]) + first.lowercased() + String(text[text.index(after: start)...])
    }
}

/// The kind of app the text is going to, which picks a writing style.
public enum AppCategory: String, Codable, CaseIterable, Sendable {
    case messages, email, work, other

    /// Maps a macOS bundle identifier. Unknown or missing identifiers are `.other`.
    public init(bundleID: String?) {
        let id = (bundleID ?? "").lowercased()
        let match = AppCategory.known.first { id == $0.id || (id.hasPrefix($0.id + ".") && $0.prefix) }
        self = match?.category ?? .other
    }

    private static let known: [(id: String, category: AppCategory, prefix: Bool)] = [
        ("net.whatsapp.whatsapp", .messages, false), ("desktop.whatsapp", .messages, false),
        ("com.apple.mobilesms", .messages, false), ("com.apple.messages", .messages, false),
        ("com.tinyspeck.slackmacgap", .messages, false),
        ("ru.keepcoder.telegram", .messages, false), ("org.telegram.desktop", .messages, false),
        ("com.hnc.discord", .messages, false), ("org.whispersystems.signal-desktop", .messages, false),
        ("com.facebook.archon", .messages, false),
        ("com.apple.mail", .email, false), ("com.microsoft.outlook", .email, false),
        ("com.readdle.sparkdesktop", .email, true), ("com.google.gmail", .email, false),
        ("com.apple.notes", .work, false), ("com.apple.iwork.pages", .work, false),
        ("com.microsoft.word", .work, false), ("com.microsoft.teams", .work, false),
        ("com.microsoft.teams2", .work, false), ("notion.id", .work, false), ("md.obsidian", .work, false),
    ]
}

/// Which writing style each kind of app gets. Defaults: messages casual, everything else formal.
public struct StyleSettings: Equatable, Codable, Sendable {
    public static let defaults: [AppCategory: WritingStyle] = [
        .messages: .casual, .email: .formal, .work: .formal, .other: .formal,
    ]

    public let byCategory: [AppCategory: WritingStyle]

    public init(byCategory: [AppCategory: WritingStyle] = StyleSettings.defaults) {
        self.byCategory = byCategory
    }

    public func style(for category: AppCategory) -> WritingStyle {
        byCategory[category] ?? StyleSettings.defaults[category] ?? .formal
    }

    public func style(forBundleID bundleID: String?) -> WritingStyle {
        style(for: AppCategory(bundleID: bundleID))
    }

    /// A new value with that category's style changed.
    public func setting(_ style: WritingStyle, for category: AppCategory) -> StyleSettings {
        StyleSettings(byCategory: byCategory.merging([category: style]) { _, new in new })
    }

    // Stored as {"messages": "casual", ...}: readable, and stable if cases are added.
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode([String: String].self)
        let pairs = raw.compactMap { key, value -> (AppCategory, WritingStyle)? in
            guard let c = AppCategory(rawValue: key), let s = WritingStyle(rawValue: value) else { return nil }
            return (c, s)
        }
        self.init(byCategory: Dictionary(uniqueKeysWithValues: pairs))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Dictionary(uniqueKeysWithValues: byCategory.map { ($0.key.rawValue, $0.value.rawValue) }))
    }
}
