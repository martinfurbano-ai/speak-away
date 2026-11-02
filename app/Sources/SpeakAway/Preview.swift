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
        let window = HubWindow(store: StatsStore(preview: stats), engine: Engine(), previewReady: true)
        if let s = ProcessInfo.processInfo.environment["SECTION"], let section = HubSection(rawValue: s) { window.model.section = section }
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            window.appearance = NSAppearance(named: appearance)
            window.center()
            window.orderFrontRegardless()
            RunLoop.main.run(until: Date().addingTimeInterval(1.5))
            // Real window capture: offscreen caching misses the Liquid Glass layers.
            let shot = Process()
            shot.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            shot.arguments = ["-x", "-o", "-l", String(window.windowNumber), "\(base)-\(name).png"]
            try? shot.run()
            shot.waitUntilExit()
        }
        window.orderOut(nil)
        exit(0)
    }
}
