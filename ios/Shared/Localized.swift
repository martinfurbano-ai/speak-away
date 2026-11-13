import Foundation
import SpeakAwayCore

/// The language the interface is shown in. The app and the keyboard follow the device language, English
/// unless the device speaks Spanish.
enum UILanguage {
    /// "es" or "en".
    static var code: String {
        let first = Bundle.main.preferredLocalizations.first ?? "en"
        return first.lowercased().hasPrefix("es") ? "es" : "en"
    }

    static var isSpanish: Bool { code == "es" }

    /// For numbers and dates: Spanish shows 50.000 and "miércoles" even where the region would not.
    static var locale: Locale { Locale(identifier: code) }
}

/// The names of the three writing styles in the interface language. The titles in Core are English only.
enum StyleText {
    static func title(_ style: WritingStyle) -> String {
        switch style {
        case .formal: return String(localized: "Formal")
        case .casual: return String(localized: "Casual")
        case .veryCasual: return String(localized: "Very casual")
        }
    }

    /// "Auto: Casual" while the style follows the field, "Casual" once the user picked it.
    static func chip(override: WritingStyle?, effective: WritingStyle) -> String {
        let title = title(effective)
        return override == nil ? String(localized: "Auto: \(title)") : title
    }
}
