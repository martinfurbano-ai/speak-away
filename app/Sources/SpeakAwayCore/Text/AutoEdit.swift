import Foundation

/// Wispr Flow style automatic edits on a transcript: filler words, stutters, backtracking
/// ("at 2, actually 3" keeps "at 3"), spacing and capital letters.
///
/// Conservative on purpose: when a rule is not sure, the words stay.
public enum AutoEdit {
    /// - Parameter language: "es", "en", "es-PA"... or nil. With nil both the English and the Spanish
    ///   rules apply. Other languages only get the spacing and capital letter fixes.
    public static func clean(_ text: String, language: String?) -> String {
        let (lead, core, trail) = TextEnvelope.split(text)
        if core.isEmpty { return text }
        let lang = TextLanguage(language)
        let edited = [
            { Fillers.remove($0, lang) },
            { Stutters.collapse($0, lang) },
            { Backtracking.apply($0, lang) },
            { Spacing.fix($0) },
            { Capitals.sentenceStarts($0) },
        ].reduce(core) { current, step in step(current) }
        return lead + edited + trail
    }
}

// MARK: Fillers

enum Fillers {
    private static let commonWord = "m{3,}"
    private static let englishWord = "u{1,3}[hm]{1,3}|erm+"
    private static let spanishWord = "e{1,3}h{1,3}m{0,2}"

    static func remove(_ text: String, _ lang: TextLanguage) -> String {
        var rules: [(word: String, after: String)] = [(commonWord, "")]
        if lang.includesEnglish { rules.append((englishWord, "")) }
        // "¿eh?" is a question tag, not a hesitation.
        if lang.includesSpanish { rules.append((spanishWord, "(?![?!])")) }
        let removed = rules.reduce(text) { current, rule in removeWord(current, rule.word, extraAfter: rule.after) }
        let phrases = [
            lang.includesEnglish ? "you know" : nil,
            lang.includesSpanish ? "este" : nil,
        ].compactMap { $0 }
        return phrases.reduce(removed) { current, phrase in removeIsolatedPhrase(current, phrase, endsSentence: phrase == "you know") }
    }

    private static func removeWord(_ text: String, _ word: String, extraAfter: String) -> String {
        let w = "(?<![\\p{L}\\p{N}\\-])(?:\(word))(?![\\p{L}\\p{N}\\-])\(extraAfter)"
        let end = "(?=\\s*[.!?…]|\\s*$)"
        let steps: [(String, String)] = [
            ("\\s*,\\s*\(w)\\s*,\\s*", ", "),       // "was, um, great" -> "was, great"
            ("^\(w)[\\s,.…]*", ""),                    // "Um, I think" -> "I think"
            ("(?<=[.!?…])\\s+\(w)[\\s,.…]*", " "),     // "Okay. Um, go" -> "Okay. go"
            ("\\s*,?\\s*\(w)\(end)", ""),              // "fine, um." -> "fine."
            ("\\s+\(w)\\s*,\\s*", ", "),             // "think um, we" -> "think, we"
            ("\\s+\(w)(?=\\s)", ""),                  // "I um think" -> "I think"
        ]
        // A removal can expose another one ("um, um, ok"), so repeat until nothing changes.
        var current = text
        for _ in 0..<4 {
            let next = steps.reduce(current) { Rx.replacing($0, $1.0, with: $1.1) }
            if next == current { break }
            current = next
        }
        return current
    }

    /// Words that are filler only between commas (", you know," / ", este,").
    private static func removeIsolatedPhrase(_ text: String, _ phrase: String, endsSentence: Bool) -> String {
        let both = Rx.replacing(text, "\\s*,\\s*\(phrase)\\s*,\\s*", with: ", ")
        guard endsSentence else { return both }
        return Rx.replacing(both, "\\s*,\\s*\(phrase)(?=\\s*[.!?…]|\\s*$)", with: "")
    }
}

// MARK: Stutters

enum Stutters {
    // Only small function words: real repeats of other words ("very very", "had had", "no no") stay.
    private static let english = ["the", "a", "an", "i", "we", "you", "he", "she", "they", "it", "to", "of", "in", "on",
                                  "at", "and", "but", "is", "are", "was", "were", "my", "our", "your", "his", "her",
                                  "their", "if", "for", "with", "from", "by", "as"]
    private static let spanish = ["el", "la", "los", "las", "un", "una", "de", "en", "que", "a", "con", "por", "para",
                                  "se", "me", "te", "nos", "le", "mi", "tu", "su", "es", "lo", "yo"]

    static func collapse(_ text: String, _ lang: TextLanguage) -> String {
        let words = (lang.includesEnglish ? english : []) + (lang.includesSpanish ? spanish : [])
        if words.isEmpty { return text }
        let edge = "[\\p{L}\\p{N}']"
        let pattern = "(?<!\(edge)|-)(\(words.joined(separator: "|")))(?!\(edge))(?:(?:,?\\s+|-)\\1(?!\(edge)))+"
        return Rx.replacing(text, pattern, with: "$1")
    }
}

// MARK: Spacing

enum Spacing {
    static func fix(_ text: String) -> String {
        let steps: [(String, String)] = [
            ("[ \\t]{2,}", " "),
            ("[ \\t]+([,.;:!?%)\\]…])", "$1"),
            ("([¿¡(])[ \\t]+", "$1"),
            (",{2,}", ","),
            (",\\s*([.!?…])", "$1"),
            ("(?<=\\p{L})([,;])(?=\\p{L})", "$1 "),
        ]
        let fixed = steps.reduce(text) { Rx.replacing($0, $1.0, with: $1.1) }
        return fixed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: Capitals

enum Capitals {
    private static let abbreviations: Set<String> = [
        "e.g.", "i.e.", "etc.", "vs.", "dr.", "dra.", "mr.", "mrs.", "ms.", "sr.", "sra.", "srta.", "no.", "núm.",
        "pág.", "aprox.", "approx.", "a.m.", "p.m.", "u.s.", "ee.uu.", "inc.", "ltd.", "ud.", "uds.",
    ]

    /// Capital letter at the start of the text and of each sentence. Only plain lowercase words change:
    /// "iPhone", "example.com" and the word after "etc." or "Dr." stay as they are.
    static func sentenceStarts(_ text: String) -> String {
        var output = ""
        var atStart = true
        var index = text.startIndex
        while index < text.endIndex {
            let isSpace = text[index].isWhitespace
            var end = index
            while end < text.endIndex, text[end].isWhitespace == isSpace { end = text.index(after: end) }
            let run = String(text[index..<end])
            if isSpace {
                output += run
                if run.contains("\n") { atStart = true }
            } else {
                output += atStart ? capitalized(run) : run
                atStart = endsSentence(run)
            }
            index = end
        }
        return output
    }

    private static func endsSentence(_ token: String) -> Bool {
        let stripped = String(token.reversed().drop(while: { "\"')”’]".contains($0) }).reversed())
        guard let last = stripped.last, ".!?".contains(last) else { return false }
        if stripped.hasSuffix("..") || stripped.hasSuffix("…") { return false }
        if last == "." {
            let lower = stripped.lowercased()
            if abbreviations.contains(lower) { return false }
            if stripped.dropLast().allSatisfy({ $0.isNumber }) { return false }
        }
        return true
    }

    private static func capitalized(_ token: String) -> String {
        let leadingMarks = token.prefix(while: { "¿¡\"'(“‘[".contains($0) })
        let body = token.dropFirst(leadingMarks.count)
        let word = body.reversed().drop(while: { ".,;:!?)\"”’'…]".contains($0) }).reversed()
        guard let first = word.first, first.isLowercase,
              word.allSatisfy({ $0.isLetter || $0 == "'" || $0 == "’" || $0 == "-" }),
              !word.contains(where: { $0.isUppercase })
        else { return token }
        return String(leadingMarks) + first.uppercased() + body.dropFirst()
    }
}
