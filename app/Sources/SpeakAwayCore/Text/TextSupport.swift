import Foundation

/// Small helpers shared by the text features. Internal: not part of the public API.
enum TextEnvelope {
    /// Splits leading whitespace, the text itself and trailing whitespace.
    /// SpeechGate.clean adds one trailing space, and every text feature keeps it as it found it.
    static func split(_ text: String) -> (lead: String, core: String, trail: String) {
        let lead = String(text.prefix(while: { $0.isWhitespace }))
        let rest = text.dropFirst(lead.count)
        let trailCount = rest.reversed().prefix(while: { $0.isWhitespace }).count
        let core = String(rest.dropLast(trailCount))
        let trail = String(rest.suffix(trailCount))
        return (lead, core, trail)
    }
}

extension String {
    /// Lowercased and without accents, for comparing words.
    var folded: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}

/// A run of letters or digits in a text, with where it sits.
struct WordToken {
    let folded: String
    let range: Range<String.Index>

    static func tokens(in text: String) -> [WordToken] {
        var result: [WordToken] = []
        var start: String.Index?
        var index = text.startIndex
        while index < text.endIndex {
            let ch = text[index]
            let next = text.index(after: index)
            if ch.isLetter || ch.isNumber {
                if start == nil { start = index }
            } else if let s = start {
                result.append(WordToken(folded: String(text[s..<index]).folded, range: s..<index))
                start = nil
            }
            index = next
        }
        if let s = start {
            result.append(WordToken(folded: String(text[s...]).folded, range: s..<text.endIndex))
        }
        return result
    }
}

/// Regular expression helpers. Every pattern in this module is a constant, so a pattern that
/// does not compile is a programmer error and fails loudly in the tests.
enum Rx {
    static func make(_ pattern: String, caseInsensitive: Bool = true) -> NSRegularExpression {
        do {
            return try NSRegularExpression(pattern: pattern, options: caseInsensitive ? [.caseInsensitive] : [])
        } catch {
            preconditionFailure("Bad pattern \(pattern): \(error)")
        }
    }

    static func replacing(_ text: String, _ pattern: String, with template: String, caseInsensitive: Bool = true) -> String {
        make(pattern, caseInsensitive: caseInsensitive).stringByReplacingMatches(
            in: text, options: [], range: NSRange(text.startIndex..., in: text), withTemplate: template)
    }

    static func matches(_ text: String, _ pattern: String, caseInsensitive: Bool = true) -> Bool {
        make(pattern, caseInsensitive: caseInsensitive)
            .firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) != nil
    }
}

/// Which language rules to use for a language code ("es", "en-US", nil when unknown).
enum TextLanguage {
    case en, es, both, other

    init(_ code: String?) {
        guard let code = code?.lowercased(), !code.isEmpty else { self = .both; return }
        if code.hasPrefix("es") { self = .es }
        else if code.hasPrefix("en") { self = .en }
        else { self = .other }
    }

    var includesEnglish: Bool { self == .en || self == .both }
    var includesSpanish: Bool { self == .es || self == .both }
}
