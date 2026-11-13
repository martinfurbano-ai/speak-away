import Foundation

/// How the numbers on the home screen are written.
public enum StatFormat {
    /// Thousands grouped the way the language does: 50.000 in Spanish, 50,000 in English.
    public static func number(_ value: Int, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// "45 min" under an hour, "1 h 20 min" from an hour on.
    public static func timeSaved(minutes: Int) -> String {
        let m = max(0, minutes)
        return m < 60 ? "\(m) min" : "\(m / 60) h \(m % 60) min"
    }

    /// Whole minutes of a length in seconds, rounded down.
    public static func minutes(of seconds: Double) -> Int {
        max(0, Int(seconds / 60))
    }
}
