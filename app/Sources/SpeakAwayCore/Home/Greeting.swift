import Foundation

/// The greeting at the top of the home screen. The Mac and the iPhone share the hours.
public enum Greeting: Equatable, Sendable {
    case morning, afternoon, evening

    /// Before noon, then until seven in the evening, then the night.
    public static func forHour(_ hour: Int) -> Greeting {
        hour < 12 ? .morning : hour < 19 ? .afternoon : .evening
    }

    public static func at(_ date: Date, calendar: Calendar = .current) -> Greeting {
        forHour(calendar.component(.hour, from: date))
    }
}
