import Foundation

/// The iPhone app's settings, kept in one JSON file in the shared folder.
/// A file with only some keys is fine: the rest keep their defaults.
public struct PhoneSettings: Codable, Equatable, Sendable {
    /// "auto" (the system language) or a language/locale such as "es" or "en-GB".
    public var language: String
    /// Remove filler words and apply spoken corrections.
    public var autoEdit: Bool
    /// Light rewrite with Apple's on-device model after dictating. Off by default, like the Mac: slower.
    public var polish: Bool
    public var sessionLength: SessionLength
    public var sounds: Bool
    public var haptics: Bool
    public var historyEnabled: Bool
    /// The unique id of the input to listen with. Empty means the one the system picks.
    public var microphone: String

    public init(language: String = "auto", autoEdit: Bool = true, polish: Bool = false,
                sessionLength: SessionLength = .fifteenMinutes, sounds: Bool = true, haptics: Bool = true,
                historyEnabled: Bool = true, microphone: String = "") {
        self.language = language
        self.autoEdit = autoEdit
        self.polish = polish
        self.sessionLength = sessionLength
        self.sounds = sounds
        self.haptics = haptics
        self.historyEnabled = historyEnabled
        self.microphone = microphone
    }

    /// A copy with `change` applied; the original stays as it was.
    public func changing(_ change: (inout PhoneSettings) -> Void) -> PhoneSettings {
        var copy = self
        change(&copy)
        return copy
    }

    /// The language the text rules (filler words, spoken corrections) use: the locale the speech
    /// engine listened in, else the setting, else `nil` (both English and Spanish rules).
    public func pipelineLanguage(resolvedLocale: String?) -> String? {
        if let resolvedLocale { return SpeechLocale.languageCode(resolvedLocale) }
        return language.lowercased() == "auto" ? nil : SpeechLocale.languageCode(language)
    }

    private enum Key: String, CodingKey {
        case language, autoEdit, polish, sessionLength, sounds, haptics, historyEnabled, microphone
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        let defaults = PhoneSettings()
        language = try c.decodeIfPresent(String.self, forKey: .language) ?? defaults.language
        autoEdit = try c.decodeIfPresent(Bool.self, forKey: .autoEdit) ?? defaults.autoEdit
        polish = try c.decodeIfPresent(Bool.self, forKey: .polish) ?? defaults.polish
        sessionLength = (try c.decodeIfPresent(String.self, forKey: .sessionLength)).flatMap(SessionLength.init(rawValue:))
            ?? defaults.sessionLength
        sounds = try c.decodeIfPresent(Bool.self, forKey: .sounds) ?? defaults.sounds
        haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? defaults.haptics
        historyEnabled = try c.decodeIfPresent(Bool.self, forKey: .historyEnabled) ?? defaults.historyEnabled
        microphone = try c.decodeIfPresent(String.self, forKey: .microphone) ?? defaults.microphone
    }
}
