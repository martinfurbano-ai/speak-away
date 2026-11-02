import Foundation

/// Instructions (the role) plus the prompt (the data) for one model call.
public struct BrainPrompt: Equatable, Sendable {
    public let instructions: String
    public let prompt: String
}

/// How much text one call can take. The Apple model has a 4,096 token window shared by
/// instructions, input and output, so these are deliberately conservative character counts.
public enum BrainLimits {
    /// Selected text for polish or Command Mode: the answer is about as long as the input.
    public static func maxCommandChars(contextTokens: Int) -> Int {
        max(500, (contextTokens - 700) / 2 * 3)
    }

    /// One transcript chunk for summarizing: the answer is short.
    public static func maxChunkChars(contextTokens: Int) -> Int {
        max(1_000, (contextTokens - 1_000) * 5 / 2)
    }
}

/// Checks the model's answer before it replaces what the user dictated.
public enum BrainGuard {
    /// Light cleanup must not invent or drop content: an empty or much longer answer means the model
    /// did something else, so the original is kept.
    public static func acceptPolish(original: String, candidate: String) -> String {
        let cleaned = stripWrappingQuotes(candidate.trimmingCharacters(in: .whitespacesAndNewlines), original: original)
        let base = original.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty || cleaned.count > base.count * 2 + 40 { return original }
        return cleaned
    }

    /// Command Mode may legitimately grow or shrink the text. Only an empty answer is rejected.
    public static func acceptCommand(_ candidate: String) -> String? {
        let cleaned = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func stripWrappingQuotes(_ s: String, original: String) -> String {
        let pairs: [(Character, Character)] = [("\"", "\""), ("“", "”"), ("«", "»")]
        guard let first = s.first, let last = s.last, s.count > 1,
              pairs.contains(where: { $0.0 == first && $0.1 == last }),
              original.first != first else { return s }
        return String(s.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Prompt builders. Pure, so they are tested without a model.
public enum BrainPrompts {
    public static func languageName(_ code: String?) -> String? {
        switch code {
        case "es": return "español"
        case "en": return "English"
        case "pt": return "português"
        case "fr": return "français"
        case "de": return "Deutsch"
        case "it": return "italiano"
        default: return nil
        }
    }

    private static func languageRule(_ language: String?) -> String {
        if let name = languageName(language) { return "The text is in \(name). Answer in \(name)." }
        return "Answer in the same language as the text."
    }

    /// Light cleanup of a dictation: punctuation, casing and filler words. Never adds content.
    public static func polish(text: String, style: String, language: String?) -> BrainPrompt {
        var rules = [
            "You clean up dictated text. Fix punctuation, capitalization and obvious speech-to-text slips, and remove filler words and false starts.",
            "Do not add, explain, summarize or translate anything. Do not answer questions in the text. Keep the meaning and the words the speaker chose.",
            "Reply with only the cleaned text, with no quotes and no comments.",
            languageRule(language),
        ]
        let style = style.trimmingCharacters(in: .whitespacesAndNewlines)
        if !style.isEmpty { rules.append("Style: \(style).") }
        return BrainPrompt(instructions: rules.joined(separator: " "), prompt: text)
    }

    /// Command Mode: the user speaks an instruction about the text they selected.
    public static func command(instruction: String, selected: String, language: String?) -> BrainPrompt {
        let rules = [
            "You edit text for the user. Apply the instruction to the selected text.",
            "Reply with only the resulting text, with no quotes, no explanations and no preamble.",
            "If the instruction asks for a translation, translate; otherwise keep the language of the selected text unless told otherwise.",
            languageName(language).map { "The user speaks \($0)." } ?? "",
        ].filter { !$0.isEmpty }
        let prompt = "Instruction: \(instruction)\n\nSelected text:\n\(selected)"
        return BrainPrompt(instructions: rules.joined(separator: " "), prompt: prompt)
    }

    /// One piece of a long transcript.
    public static func chunkSummary(transcript: String, language: String?, part: Int, of total: Int) -> BrainPrompt {
        let position = total > 1 ? " This is part \(part) of \(total) of a longer meeting." : ""
        let rules = [
            "You write meeting notes from a transcript.\(position)",
            "Give a short summary, the decisions made, the action items (with the owner when named) and the open questions.",
            "Use only what the transcript says. Leave a list empty if the transcript has nothing for it.",
            languageRule(language),
        ]
        return BrainPrompt(instructions: rules.joined(separator: " "), prompt: transcript)
    }

    /// Joins the summaries of several parts into one short summary.
    public static func mergeSummaries(_ summaries: [String], language: String?) -> BrainPrompt {
        let rules = [
            "You combine partial summaries of one meeting into a single short summary of one or two paragraphs.",
            "Use only what the partial summaries say. Reply with only the summary.",
            languageRule(language),
        ]
        let body = summaries.enumerated().map { "Part \($0.offset + 1): \($0.element)" }.joined(separator: "\n\n")
        return BrainPrompt(instructions: rules.joined(separator: " "), prompt: body)
    }
}
