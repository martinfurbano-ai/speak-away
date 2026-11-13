import Foundation

/// The name a recorded meeting gets: what the user typed, or the time it began.
public enum MeetingTitle {
    public static let maxLength = 80

    public static func resolved(_ typed: String, startedAt: Date, english: Bool, timeZone: TimeZone = .current) -> String {
        let oneLine = typed.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !oneLine.isEmpty else { return "\(english ? "Meeting" : "Reunión") \(time(startedAt, timeZone: timeZone))" }
        return String(oneLine.prefix(maxLength)).trimmingCharacters(in: .whitespaces)
    }

    private static func time(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
