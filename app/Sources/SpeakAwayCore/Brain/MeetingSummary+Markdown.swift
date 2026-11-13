import Foundation

extension MeetingSummary {
    /// Reads notes saved as Markdown by `markdown(english:)` back into their four parts.
    /// "Tareas", "Pendientes" and "Action items" all name the action items. A heading we do not know
    /// is skipped with what is under it. Text with none of the four sections is not notes: `nil`.
    public init?(markdown text: String) {
        var current: Section?
        var found = false
        var summaryLines: [String] = []
        var decisions: [String] = []
        var actions: [String] = []
        var questions: [String] = []

        for line in text.components(separatedBy: .newlines) {
            if let title = MeetingSummary.headingTitle(line) {
                current = MeetingSummary.section(named: title)
                found = found || current != nil
                continue
            }
            if current == .summary {
                summaryLines.append(line)
            } else if let current, let item = MeetingSummary.bulletText(line) {
                switch current {
                case .decisions: decisions.append(item)
                case .actions: actions.append(item)
                case .questions: questions.append(item)
                case .summary: break
                }
            }
        }
        guard found else { return nil }
        self = MeetingSummary(summary: summaryLines.joined(separator: "\n"), decisions: decisions,
                              actionItems: actions, questions: questions).cleaned()
    }

    private enum Section { case summary, decisions, actions, questions }

    private static func section(named title: String) -> Section? {
        switch foldedKey(title) {
        case "resumen", "summary": .summary
        case "decisiones", "decisions": .decisions
        case "tareas", "pendientes", "action items": .actions
        case "preguntas abiertas", "open questions": .questions
        default: nil
        }
    }

    /// The words of a Markdown heading line (`## Resumen`), or `nil` when the line is not a heading.
    private static func headingTitle(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }
        let rest = trimmed.drop(while: { $0 == "#" })
        guard rest.first == " " else { return nil }
        return rest.trimmingCharacters(in: CharacterSet(charactersIn: " #"))
    }

    /// A list line without its bullet, number or check box. Empty lines give `nil`.
    private static func bulletText(_ line: String) -> String? {
        var text = line.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        if let first = text.first, "-*•+".contains(first), text.dropFirst().first == " " {
            text = String(text.dropFirst(2))
        } else if let dot = text.firstIndex(where: { $0 == "." || $0 == ")" }),
                  !text[..<dot].isEmpty, text[..<dot].allSatisfy(\.isNumber),
                  text[text.index(after: dot)...].first == " " {
            text = String(text[text.index(after: dot)...])
        }
        text = text.trimmingCharacters(in: .whitespaces)
        for box in ["[ ] ", "[x] ", "[X] "] where text.hasPrefix(box) {
            text = String(text.dropFirst(box.count))
        }
        let result = text.trimmingCharacters(in: .whitespaces)
        return result.isEmpty ? nil : result
    }
}
