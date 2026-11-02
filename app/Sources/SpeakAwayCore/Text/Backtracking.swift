import Foundation

/// "Let's meet at 2, actually 3" becomes "Let's meet at 3".
///
/// A comma, a correction marker ("actually", "I mean", "perdón", "no, mejor"...) and a short correction
/// replace the part of the sentence they correct. The part being corrected must be found with certainty:
///
/// 1. the correction starts with a word that introduces a slot ("at", "on", "a", "el"...) or a day or month,
///    and the same word appears earlier in the sentence: everything from that word on is replaced; or
/// 2. the correction starts with a number, a day, a month or a name, and the sentence ends with the same
///    kind of word: that word is replaced.
///
/// Anything else is left alone, so "It was good, actually, very good" keeps every word.
enum Backtracking {
    private static let englishMarkers = [
        "no\\s*,?\\s*wait", "wait\\s*,?\\s*no", "actually", "i mean", "sorry", "or rather", "make that",
        "scratch that", "wait", "rather", "no",
    ]
    private static let spanishMarkers = [
        "no\\s*,?\\s*mejor", "no\\s*,?\\s*espera", "mejor dicho", "perd[oó]n", "perdona", "perdone", "digo",
        "quiero decir", "espera", "mejor", "no",
    ]

    private static let introducers: Set<String> = [
        "at", "on", "in", "to", "for", "by", "from", "until", "till", "before", "after", "with", "the", "a", "an",
        "en", "el", "la", "los", "las", "un", "una", "de", "del", "por", "para", "con", "hasta", "desde", "antes", "despues",
    ]
    private static let weekdays: Set<String> = [
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
        "lunes", "martes", "miercoles", "jueves", "viernes", "sabado", "domingo",
    ]
    private static let months: Set<String> = [
        "january", "february", "march", "april", "may", "june", "july", "august", "september", "october",
        "november", "december", "enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto",
        "septiembre", "setiembre", "octubre", "noviembre", "diciembre",
    ]
    private static let numberWords: Set<String> = [
        "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve",
        "uno", "una", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve", "diez", "once", "doce",
    ]
    private static let meridiems: Set<String> = ["am", "pm", "a.m", "p.m"]

    private enum Kind { case number, weekday, month }

    static func apply(_ text: String, _ lang: TextLanguage) -> String {
        if lang == .other { return text }
        // "no" is last: the longer markers that start with it get their chance first.
        let all = (lang.includesEnglish ? englishMarkers : []) + (lang.includesSpanish ? spanishMarkers : [])
        let markers = (all.filter { $0 != "no" } + ["no"]).joined(separator: "|")
        let marker = Rx.make("\\s*,\\s*(?:\(markers))(?![\\p{L}\\p{N}])\\s*,?\\s*")
        var current = text
        var from = 0
        for _ in 0..<8 {
            let ns = current as NSString
            guard from < ns.length,
                  let match = marker.firstMatch(in: current, options: [], range: NSRange(location: from, length: ns.length - from))
            else { break }
            let matchEnd = match.range.location + match.range.length
            if let fixed = correct(ns, markerStart: match.range.location, markerEnd: matchEnd) {
                current = fixed.text
                from = fixed.resumeAt
            } else {
                from = matchEnd
            }
        }
        return current
    }

    private static func correct(_ ns: NSString, markerStart: Int, markerEnd: Int) -> (text: String, resumeAt: Int)? {
        let before = ns.substring(to: markerStart)
        let rest = ns.substring(from: markerEnd)

        // The sentence being corrected starts after the last sentence end.
        let sentenceEnd = Rx.make("(?:[.!?…]+[ \\t]+|\\n\\s*)")
        let beforeRange = NSRange(location: 0, length: (before as NSString).length)
        let sentenceStart = sentenceEnd.matches(in: before, options: [], range: beforeRange)
            .last.map { $0.range.location + $0.range.length } ?? 0
        let head = (before as NSString).substring(to: sentenceStart)
        let sentence = (before as NSString).substring(from: sentenceStart)

        // The correction runs to the next comma or sentence end.
        let stop = Rx.make("[,;:!?…]|\\.(?=\\s|$)")
        let restRange = NSRange(location: 0, length: (rest as NSString).length)
        let cut = stop.firstMatch(in: rest, options: [], range: restRange)?.range.location ?? restRange.length
        let correction = (rest as NSString).substring(to: cut)
        let tail = (rest as NSString).substring(from: cut)

        let old = sentence.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let new = correction.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !old.isEmpty, !new.isEmpty else { return nil }
        guard let merged = aligned(old, new) ?? sameKind(old, new) else { return nil }

        let rewritten = head + merged.joined(separator: " ")
        return (rewritten + tail, (rewritten as NSString).length)
    }

    // MARK: rule 1

    private static func aligned(_ old: [String], _ new: [String]) -> [String]? {
        let key = word(new[0])
        guard introducers.contains(key) || weekdays.contains(key) || months.contains(key),
              let i = old.lastIndex(where: { word($0) == key }),
              old.count - i <= new.count + 2
        else { return nil }
        return Array(old[..<i]) + new
    }

    // MARK: rule 2

    private static func sameKind(_ old: [String], _ new: [String]) -> [String]? {
        if let kind = classify(new[0]) {
            return replaceTail(old, new, kind: kind)
        }
        return replaceName(old, new)
    }

    private static func replaceTail(_ old: [String], _ new: [String], kind: Kind) -> [String]? {
        switch kind {
        case .number:
            let meridiemCount = old.reversed().prefix(while: { meridiems.contains(word($0)) }).count
            guard old.count > meridiemCount, classify(old[old.count - meridiemCount - 1]) == .number else { return nil }
            return Array(old.dropLast(meridiemCount + 1)) + new
        case .weekday, .month:
            guard classify(old[old.count - 1]) == kind else { return nil }
            return Array(old.dropLast()) + new
        }
    }

    /// "to John Smith, I mean Mike Jones": capitalised words in the middle of a sentence are names.
    private static func replaceName(_ old: [String], _ new: [String]) -> [String]? {
        guard isName(new[0]) else { return nil }
        let run = old.indices.reversed().prefix(while: { $0 > 0 && isName(old[$0]) }).count
        guard run > 0, new.count <= run + 1 else { return nil }
        return Array(old.dropLast(run)) + new
    }

    // MARK: words

    private static func word(_ token: String) -> String {
        trimmed(token).folded
    }

    private static func trimmed(_ token: String) -> String {
        let isEdge: (Character) -> Bool = { !($0.isLetter || $0.isNumber) }
        let front = token.drop(while: isEdge)
        return String(front.reversed().drop(while: isEdge).reversed())
    }

    private static func classify(_ token: String) -> Kind? {
        let w = word(token)
        if Rx.matches(w, "^\\d+(?:[:.,]\\d+)?$") || numberWords.contains(w) { return .number }
        if weekdays.contains(w) { return .weekday }
        if months.contains(w) { return .month }
        return nil
    }

    private static func isName(_ token: String) -> Bool {
        let w = trimmed(token)
        guard let first = w.first, first.isUppercase, w != "I", classify(token) == nil,
              !introducers.contains(w.folded)
        else { return false }
        return w.allSatisfy { $0.isLetter || $0 == "'" || $0 == "-" }
    }
}
