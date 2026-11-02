import AppKit
import SpeakAwayCore

/// `SpeakAway --preview-home out` writes out-light.png and out-dark.png of the home window with sample numbers.
/// Used to check the design without dictating for weeks.
@MainActor
enum Preview {
    static func home(to base: String) -> Never {
        _ = NSApplication.shared
        let today = DayKey(Date())
        var stats = UsageStats()
        for back in 0..<140 where back < 6 || (back % 3 != 0 && back % 7 != 5) {
            let words = 120 + (back * 37) % 900
            stats = stats.recording(words: words, seconds: Double(words) / 2.4, on: today.adding(-back))
        }
        let window = HomeWindow(store: StatsStore(preview: stats), engine: Engine())
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            window.appearance = NSAppearance(named: appearance)
            window.setFrameOrigin(NSPoint(x: -4000, y: -4000))
            window.orderFrontRegardless()
            RunLoop.main.run(until: Date().addingTimeInterval(0.6))
            guard let view = window.contentView?.superview,
                  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(base)-\(name).png"))
        }
        exit(0)
    }
}
