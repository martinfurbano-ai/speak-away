import Foundation

/// The label on the keyboard's return key. It follows the field's `returnKeyType`.
/// It takes the raw value of `UIReturnKeyType` and gives the string-catalog key of the label, so
/// this file stays Foundation only and can be tested on the Mac. The keys are lowercase English
/// words and the catalog holds the label in each language.
public enum ReturnKeyLabel {
    /// The key for a field that has no special return key.
    public static let plain = "return"

    // UIReturnKeyType raw values: default 0, go 1, google 2, join 3, next 4, route 5, search 6,
    // send 7, yahoo 8, done 9, emergencyCall 10, continue 11.
    public static func catalogKey(returnKeyType raw: Int) -> String {
        switch raw {
        case 1: return "go"
        case 2, 6, 8: return "search"   // google, search, yahoo
        case 3: return "join"
        case 4: return "next"
        case 5: return "route"
        case 7: return "send"
        case 9: return "done"
        case 10: return "call"          // emergencyCall
        case 11: return "continue"
        default: return plain
        }
    }

    /// True when the key is the ordinary return, which VoiceOver reads as "Return".
    public static func isPlain(returnKeyType raw: Int) -> Bool {
        catalogKey(returnKeyType: raw) == plain
    }
}
