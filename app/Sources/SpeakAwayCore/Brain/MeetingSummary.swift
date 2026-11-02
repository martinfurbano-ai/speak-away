import Foundation

/// What the brain returns for a meeting transcript.
public struct MeetingSummary: Codable, Equatable, Sendable {
    public let summary: String
    public let decisions: [String]
    public let actionItems: [String]
    public let questions: [String]

    public init(summary: String, decisions: [String], actionItems: [String], questions: [String]) {
        self.summary = summary
        self.decisions = decisions
        self.actionItems = actionItems
        self.questions = questions
    }

    public var isEmpty: Bool {
        summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && decisions.isEmpty && actionItems.isEmpty && questions.isEmpty
    }

    /// Notes as Markdown. Sections with nothing in them are left out.
    public func markdown(english: Bool = false) -> String {
        let titles = english
            ? ("Summary", "Decisions", "Action items", "Open questions")
            : ("Resumen", "Decisiones", "Tareas", "Preguntas abiertas")
        var sections: [String] = []
        if !summary.isEmpty { sections.append("## \(titles.0)\n\n\(summary)\n") }
        if !decisions.isEmpty { sections.append("## \(titles.1)\n\n" + decisions.map { "- \($0)" }.joined(separator: "\n") + "\n") }
        if !actionItems.isEmpty { sections.append("## \(titles.2)\n\n" + actionItems.map { "- [ ] \($0)" }.joined(separator: "\n") + "\n") }
        if !questions.isEmpty { sections.append("## \(titles.3)\n\n" + questions.map { "- \($0)" }.joined(separator: "\n") + "\n") }
        return sections.joined(separator: "\n")
    }

    /// Trimmed, without blank lines.
    public func cleaned() -> MeetingSummary {
        func tidy(_ items: [String]) -> [String] {
            items.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        return MeetingSummary(
            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
            decisions: tidy(decisions), actionItems: tidy(actionItems), questions: tidy(questions)
        )
    }

    /// Joins the lists of several partial summaries, dropping repeats (ignoring case and accents),
    /// under a new overall summary text.
    public static func merging(_ parts: [MeetingSummary], summary: String) -> MeetingSummary {
        func unique(_ lists: [[String]]) -> [String] {
            var seen = Set<String>()
            return lists.flatMap { $0 }.filter { seen.insert(foldedKey($0)).inserted }
        }
        return MeetingSummary(
            summary: summary,
            decisions: unique(parts.map(\.decisions)),
            actionItems: unique(parts.map(\.actionItems)),
            questions: unique(parts.map(\.questions))
        ).cleaned()
    }

    static func foldedKey(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
