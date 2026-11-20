import Foundation

/// Picks the locale the speech engine listens in.
public enum SpeechLocale {
    public static let fallback = "en-US"

    /// The region to use when a language is asked for without one the engine supports.
    private static let defaultRegions = ["en": "US", "es": "MX", "pt": "BR", "zh": "CN", "fr": "FR"]

    /// - Parameters:
    ///   - setting: "auto" (use the system languages) or a language such as "es" or a locale such as "es-ES".
    ///   - preferred: the system languages, first choice first.
    ///   - supported: the locales the speech engine can do, as it spells them.
    /// - Returns: a supported locale, or "en-US" when nothing fits.
    public static func resolve(setting: String, preferred: [String], supported: [String]) -> String {
        let trimmed = setting.trimmingCharacters(in: .whitespaces)
        let asked = trimmed.isEmpty || trimmed.lowercased() == "auto" ? [] : [trimmed]
        for candidate in asked + preferred {
            if let hit = match(candidate, in: supported) { return hit }
        }
        return fallback
    }

    /// Automatic English and Spanish listen together. Other system languages keep single-language recognition.
    /// An unavailable partner stays in the plan so installation fails visibly instead of silently losing Spanish.
    public static func listeningLocales(setting: String, preferred: [String], supported: [String]) -> [String] {
        let primary = resolve(setting: setting, preferred: preferred, supported: supported)
        let automatic = setting.trimmingCharacters(in: .whitespaces).lowercased()
        guard automatic.isEmpty || automatic == "auto" else { return [primary] }
        let language = languageCode(primary).lowercased()
        guard language == "en" || language == "es" else { return [primary] }
        let partner = language == "en" ? "es" : "en"
        let partnerLocale = match(partner, in: supported) ?? (partner == "es" ? "es-MX" : fallback)
        return [primary, partnerLocale]
    }

    /// "es-MX" and "es_MX" give "es".
    public static func languageCode(_ identifier: String) -> String {
        let normalized = identifier.replacingOccurrences(of: "_", with: "-")
        return normalized.split(separator: "-", maxSplits: 1).first.map(String.init) ?? normalized
    }

    private static func match(_ candidate: String, in supported: [String]) -> String? {
        let id = candidate.replacingOccurrences(of: "_", with: "-")
        if let exact = supported.first(where: { normalized($0) == id.lowercased() }) { return exact }
        let language = languageCode(id).lowercased()
        let sameLanguage = supported.filter { languageCode($0).lowercased() == language }
        guard !sameLanguage.isEmpty else { return nil }
        if let region = defaultRegions[language],
           let preferred = sameLanguage.first(where: { normalized($0) == "\(language)-\(region)".lowercased() }) {
            return preferred
        }
        return sameLanguage.first
    }

    private static func normalized(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: "_", with: "-").lowercased()
    }
}
