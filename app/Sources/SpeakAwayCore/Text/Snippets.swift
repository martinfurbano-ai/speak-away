import Foundation

/// A phrase the user says and the longer text it stands for ("mi link de calendario" for a URL).
public struct Snippet: Equatable, Codable, Sendable {
    public let trigger: String
    public let expansion: String

    public init(trigger: String, expansion: String) {
        self.trigger = trigger
        self.expansion = expansion
    }
}

public struct Snippets: Equatable, Codable, Sendable {
    public let items: [Snippet]

    public init(items: [Snippet] = []) {
        self.items = items
    }

    /// A new list with the snippet added; one with the same trigger (ignoring case and accents) is replaced.
    public func adding(_ snippet: Snippet) -> Snippets {
        let key = Snippets.key(snippet.trigger)
        if let i = items.firstIndex(where: { Snippets.key($0.trigger) == key }) {
            return Snippets(items: items.enumerated().map { $0.offset == i ? snippet : $0.element })
        }
        return Snippets(items: items + [snippet])
    }

    public func removing(trigger: String) -> Snippets {
        let key = Snippets.key(trigger)
        return Snippets(items: items.filter { Snippets.key($0.trigger) != key })
    }

    /// Replaces every trigger phrase found in the text by its expansion.
    public func expand(_ text: String) -> String {
        expandWithInfo(text).text
    }

    /// Like `expand`, and says whether the whole dictation was one snippet. Then the expansion is
    /// inserted exactly as written (no trailing period from Whisper, nothing else added).
    ///
    /// Matching ignores case, accents and punctuation between the words ("Mi link, de calendario."),
    /// and only matches whole words. Longer triggers win over shorter ones.
    public func expandWithInfo(_ text: String) -> (text: String, replacedWholeUtterance: Bool) {
        let (lead, core, trail) = TextEnvelope.split(text)
        let tokens = WordToken.tokens(in: core)
        let triggers = items
            .map { (words: WordToken.tokens(in: $0.trigger).map(\.folded), expansion: $0.expansion) }
            .filter { !$0.words.isEmpty }
            .sorted { $0.words.count > $1.words.count }
        if tokens.isEmpty || triggers.isEmpty { return (text, false) }

        var found: [(range: Range<String.Index>, expansion: String, consumesAll: Bool)] = []
        var i = 0
        while i < tokens.count {
            let hit = triggers.first { t in
                i + t.words.count <= tokens.count
                    && zip(t.words, tokens[i...]).allSatisfy { $0 == $1.folded }
            }
            if let hit {
                let last = i + hit.words.count - 1
                found.append((tokens[i].range.lowerBound..<tokens[last].range.upperBound, hit.expansion,
                              i == 0 && last == tokens.count - 1))
                i = last + 1
            } else {
                i += 1
            }
        }
        if found.isEmpty { return (text, false) }
        if found.count == 1, found[0].consumesAll { return (lead + found[0].expansion + trail, true) }

        var output = ""
        var cursor = core.startIndex
        for item in found {
            output += core[cursor..<item.range.lowerBound]
            output += item.expansion
            cursor = item.range.upperBound
            // "Un abrazo." followed by the period Whisper put after the trigger: keep one.
            if let end = item.expansion.last, ".!?".contains(end), cursor < core.endIndex, core[cursor] == end {
                cursor = core.index(after: cursor)
            }
        }
        output += core[cursor...]
        return (lead + output + trail, false)
    }

    private static func key(_ trigger: String) -> String {
        WordToken.tokens(in: trigger).map(\.folded).joined(separator: " ")
    }
}
