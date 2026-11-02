import Foundation

/// A word the user wants spelled one way, and the forms Whisper tends to mishear it as.
public struct DictionaryEntry: Equatable, Codable, Sendable {
    public let word: String
    public let replacing: [String]

    public init(word: String, replacing: [String] = []) {
        self.word = word
        self.replacing = replacing
    }
}

/// The user's personal dictionary: fixes names and jargon after transcription, and biases Whisper before it.
public struct PersonalDictionary: Equatable, Codable, Sendable {
    public let entries: [DictionaryEntry]

    public init(entries: [DictionaryEntry] = []) {
        self.entries = entries
    }

    /// A new dictionary with the entry added; an entry for the same word (ignoring case) is replaced in place.
    public func adding(_ entry: DictionaryEntry) -> PersonalDictionary {
        let key = entry.word.folded
        if let i = entries.firstIndex(where: { $0.word.folded == key }) {
            return PersonalDictionary(entries: entries.enumerated().map { $0.offset == i ? entry : $0.element })
        }
        return PersonalDictionary(entries: entries + [entry])
    }

    /// A new dictionary without the entry for that word (ignoring case).
    public func removing(word: String) -> PersonalDictionary {
        let key = word.folded
        return PersonalDictionary(entries: entries.filter { $0.word.folded != key })
    }

    /// Replaces misheard forms by the right spelling: case-insensitive, whole words only,
    /// punctuation around them is kept. When forms overlap the longer one wins.
    public func apply(to text: String) -> String {
        let forms = entries.flatMap { entry in
            entry.replacing.map { (form: $0.trimmingCharacters(in: .whitespacesAndNewlines), word: entry.word) }
        }
        .filter { !$0.form.isEmpty }
        .enumerated()
        .sorted { a, b in
            a.element.form.count != b.element.form.count
                ? a.element.form.count > b.element.form.count
                : a.offset < b.offset
        }
        .map(\.element)
        if forms.isEmpty || text.isEmpty { return text }

        let whole = NSRange(text.startIndex..., in: text)
        let accepted = forms.reduce(into: [(range: NSRange, word: String)]()) { found, item in
            let regex = Rx.make(PersonalDictionary.pattern(for: item.form))
            for match in regex.matches(in: text, options: [], range: whole) {
                let overlaps = found.contains { NSIntersectionRange($0.range, match.range).length > 0 }
                if !overlaps { found.append((match.range, item.word)) }
            }
        }
        .sorted { $0.range.location < $1.range.location }
        if accepted.isEmpty { return text }

        let ns = text as NSString
        var output = ""
        var cursor = 0
        for item in accepted {
            output += ns.substring(with: NSRange(location: cursor, length: item.range.location - cursor))
            output += item.word
            cursor = item.range.location + item.range.length
        }
        output += ns.substring(from: cursor)
        return output
    }

    /// The right spellings, comma separated, to hand to Whisper as a prompt. Words that do not fit in
    /// `limit` characters are left out; the prompt never ends in the middle of a word.
    public func whisperPrompt(limit: Int = 224) -> String {
        var seen = Set<String>()
        let words = entries
            .map { $0.word.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        let chosen = words.reduce(into: [String]()) { list, word in
            let length = (list + [word]).joined(separator: ", ").count
            if length <= limit { list.append(word) }
        }
        return chosen.joined(separator: ", ")
    }

    private static func pattern(for form: String) -> String {
        let words = form.split(whereSeparator: { $0.isWhitespace }).map { NSRegularExpression.escapedPattern(for: String($0)) }
        return "(?<![\\p{L}\\p{N}_])" + words.joined(separator: "\\s+") + "(?![\\p{L}\\p{N}_])"
    }
}
