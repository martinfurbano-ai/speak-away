import Foundation

/// Splits long text into pieces that fit the model's context window,
/// cutting at line breaks first, then sentences, then words, then characters.
public enum TextChunker {
    public static func chunks(_ text: String, maxChars: Int) -> [String] {
        let limit = max(1, maxChars)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return split(trimmed, limit: limit, level: 0)
    }

    /// Packs whole items, in order, into groups whose total length (plus a separator each) fits `maxChars`.
    /// An item longer than the limit gets a group of its own. Blank items are dropped.
    public static func groups(_ items: [String], maxChars: Int) -> [[String]] {
        var out: [[String]] = []
        var current: [String] = []
        var size = 0
        for item in items where !item.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let cost = item.count + 2
            if !current.isEmpty && size + cost > maxChars {
                out.append(current)
                current = []
                size = 0
            }
            current.append(item)
            size += cost
            if cost > maxChars {
                out.append(current)
                current = []
                size = 0
            }
        }
        if !current.isEmpty { out.append(current) }
        return out
    }

    private enum Level: CaseIterable { case lines, sentences, words }

    private static func split(_ text: String, limit: Int, level: Int) -> [String] {
        if text.count <= limit { return [text] }
        guard level < Level.allCases.count else { return hardSplit(text, limit: limit) }
        let kind = Level.allCases[level]
        let units: [String]
        let joiner: String
        switch kind {
        case .lines:
            units = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            joiner = "\n"
        case .sentences:
            units = sentences(text)
            joiner = " "
        case .words:
            units = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            joiner = " "
        }
        // Nothing to cut at this level: try the next one.
        if units.count <= 1 { return split(text, limit: limit, level: level + 1) }

        var result: [String] = []
        var current = ""
        func flush() {
            if !current.isEmpty { result.append(current); current = "" }
        }
        for unit in units {
            if unit.count > limit {
                flush()
                result.append(contentsOf: split(unit, limit: limit, level: level + 1))
            } else if current.isEmpty {
                current = unit
            } else if current.count + joiner.count + unit.count <= limit {
                current += joiner + unit
            } else {
                flush()
                current = unit
            }
        }
        flush()
        return result
    }

    private static func sentences(_ text: String) -> [String] {
        var out: [String] = []
        var current = ""
        var pendingBreak = false
        for ch in text {
            if pendingBreak && ch.isWhitespace {
                out.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
                pendingBreak = false
                continue
            }
            pendingBreak = ".!?…".contains(ch)
            current.append(ch)
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { out.append(tail) }
        return out.filter { !$0.isEmpty }
    }

    private static func hardSplit(_ text: String, limit: Int) -> [String] {
        var out: [String] = []
        var index = text.startIndex
        while index < text.endIndex {
            let end = text.index(index, offsetBy: limit, limitedBy: text.endIndex) ?? text.endIndex
            out.append(String(text[index..<end]))
            index = end
        }
        return out
    }
}
