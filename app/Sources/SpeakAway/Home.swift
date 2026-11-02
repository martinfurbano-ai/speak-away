import AppKit
import Combine
import SpeakAwayCore
import SwiftUI

/// Colors: pure white in light mode, pure black in dark mode, one red accent.
enum Theme {
    static let background = dynamic(light: .white, dark: .black)
    static let card = dynamic(light: NSColor(white: 0.965, alpha: 1), dark: NSColor(white: 0.085, alpha: 1))
    static let line = dynamic(light: NSColor(white: 0.90, alpha: 1), dark: NSColor(white: 0.16, alpha: 1))
    static let empty = dynamic(light: NSColor(white: 0.91, alpha: 1), dark: NSColor(white: 0.14, alpha: 1))
    static let accent = Color(red: 0.86, green: 0.23, blue: 0.25)

    static let backgroundNS = NSColor(name: nil) { $0.isDark ? .black : .white }

    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { $0.isDark ? dark : light })
    }
}

private extension NSAppearance {
    var isDark: Bool { bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }
}

/// Keeps the usage numbers (never the text) in UserDefaults.
@MainActor
final class StatsStore: ObservableObject {
    @Published private(set) var stats: UsageStats
    private let key = "usageStats"

    /// For `--preview-home`: shows the given numbers and never saves.
    private let saves: Bool

    init(preview: UsageStats) {
        stats = preview
        saves = false
    }

    init() {
        saves = true
        stats = UserDefaults.standard.data(forKey: key)
            .flatMap { try? JSONDecoder().decode(UsageStats.self, from: $0) } ?? UsageStats()
    }

    func record(text: String, seconds: Double) {
        stats = stats.recording(words: UsageStats.wordCount(text), seconds: seconds, on: DayKey(Date()))
        if saves, let data = try? JSONEncoder().encode(stats) { UserDefaults.standard.set(data, forKey: key) }
    }
}

struct HomeView: View {
    @ObservedObject var store: StatsStore
    @ObservedObject var engine: Engine

    private var today: DayKey { DayKey(Date()) }

    var body: some View {
        let stats = store.stats
        VStack(alignment: .leading, spacing: 20) {
            header
            streakCard(stats)
            HStack(spacing: 14) {
                numberCard(value: stats.totalWords.formatted(), label: "Palabras dictadas", icon: "text.word.spacing",
                           footer: milestoneFooter(stats))
                numberCard(value: "\(stats.wordsPerMinute)", label: "Palabras por minuto", icon: "speedometer",
                           footer: AnyView(Text("Escribiendo: unas 40").font(.system(size: 12)).foregroundStyle(.secondary)))
                numberCard(value: timeSaved(stats.minutesSaved()), label: "Tiempo ahorrado", icon: "clock.arrow.circlepath",
                           footer: AnyView(Text("\(stats.totalSessions.formatted()) dictados").font(.system(size: 12)).foregroundStyle(.secondary)))
            }
            .fixedSize(horizontal: false, vertical: true)
            activityCard(stats)
            footer
        }
        .padding(.horizontal, 28)
        .padding(.top, 30)
        .padding(.bottom, 24)
        .frame(width: 720)
        .background(Theme.background)
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 12) {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let phase: BubbleMotion.Phase = t.truncatingRemainder(dividingBy: 5) < 2.4 ? .thinking : .idle
                BubbleView(bars: BubbleMotion.bars(phase, level: 0, time: t))
            }
            .frame(width: 40, height: 35)
            VStack(alignment: .leading, spacing: 1) {
                Text(greeting).font(.system(size: 24, weight: .bold)).kerning(-0.5)
                Text("Toca Fn dos veces para dictar en cualquier app.").font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Spacer()
            statusPill
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 12 ? "Buenos días" : hour < 19 ? "Buenas tardes" : "Buenas noches"
    }

    private var statusPill: some View {
        let (text, color): (String, Color) = {
            switch engine.state {
            case .ready: return Permission.allGranted ? ("Listo para dictar", .green) : ("Faltan permisos", .orange)
            case .downloading(let p): return ("Descargando \(Int(p * 100)) %", .orange)
            case .failed: return ("Error del modelo", .red)
            default: return ("Preparando", .orange)
            }
        }()
        return HStack(spacing: 7) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text).font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.card))
    }

    private func streakCard(_ stats: UsageStats) -> some View {
        let streak = stats.currentStreak(today: today)
        let dictatedToday = stats.days[today.ordinal] != nil
        return HStack(alignment: .center, spacing: 22) {
            ZStack {
                Circle().fill(Theme.accent.opacity(streak > 0 ? 0.14 : 0.07)).frame(width: 84, height: 84)
                Image(systemName: "flame.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(streak > 0
                        ? AnyShapeStyle(LinearGradient(colors: [Color(red: 1, green: 0.62, blue: 0.3), Theme.accent], startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(Color.secondary.opacity(0.5)))
                    .symbolEffect(.bounce, value: streak)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(streak)").font(.system(size: 46, weight: .bold, design: .rounded)).monospacedDigit()
                    Text(streak == 1 ? "día seguido" : "días seguidos").font(.system(size: 17, weight: .semibold))
                }
                Text(streakMessage(streak: streak, dictatedToday: dictatedToday, best: stats.bestStreak))
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Spacer()
            week(stats)
        }
        .padding(22)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
    }

    private func streakMessage(streak: Int, dictatedToday: Bool, best: Int) -> String {
        if streak == 0 { return "Dicta algo hoy para empezar tu racha." }
        if !dictatedToday { return "Dicta algo hoy para no perderla." }
        return best > streak ? "Tu mejor racha: \(best) días." : "Es tu mejor racha. Sigue así."
    }

    private func week(_ stats: UsageStats) -> some View {
        let letters = ["L", "M", "M", "J", "V", "S", "D"]
        // Monday of this week.
        let weekday = (Calendar.current.component(.weekday, from: Date()) + 5) % 7
        let monday = today.adding(-weekday)
        return HStack(spacing: 8) {
            ForEach(0..<7, id: \.self) { i in
                let day = monday.adding(i)
                let done = stats.days[day.ordinal] != nil
                VStack(spacing: 6) {
                    Text(letters[i]).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    ZStack {
                        Circle().fill(done ? Theme.accent : Theme.empty)
                        if done { Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)).foregroundStyle(.white) }
                        if day == today && !done { Circle().strokeBorder(Theme.accent, lineWidth: 1.5) }
                    }
                    .frame(width: 24, height: 24)
                    .opacity(day > today ? 0.45 : 1)
                }
            }
        }
    }

    private func numberCard(value: String, label: String, icon: String, footer: AnyView) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.accent)
            Text(value).font(.system(size: 30, weight: .bold, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.system(size: 13, weight: .medium))
            Spacer(minLength: 0)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
    }

    private func milestoneFooter(_ stats: UsageStats) -> AnyView {
        let m = Milestone.next(after: stats.totalWords)
        return AnyView(VStack(alignment: .leading, spacing: 5) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.empty)
                    Capsule().fill(Theme.accent).frame(width: max(6, geo.size.width * m.progress))
                }
            }
            .frame(height: 6)
            Text("Meta: \(m.target.formatted())").font(.system(size: 12)).foregroundStyle(.secondary)
        })
    }

    private func timeSaved(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes) min" : "\(minutes / 60) h \(minutes % 60) min"
    }

    private func activityCard(_ stats: UsageStats) -> some View {
        let weeks = 20
        let weekday = (Calendar.current.component(.weekday, from: Date()) + 5) % 7
        let end = today.adding(6 - weekday) // Sunday of this week
        let words = stats.activity(endingOn: end, days: weeks * 7)
        let top = max(1, words.max() ?? 1)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Actividad").font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("Últimas \(weeks) semanas").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                ForEach(0..<weeks, id: \.self) { w in
                    VStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { d in
                            let index = w * 7 + d
                            let day = end.adding(index - weeks * 7 + 1)
                            let n = words[index]
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(n == 0 ? Theme.empty : Theme.accent.opacity(0.3 + 0.7 * Double(n) / Double(top)))
                                .frame(maxWidth: .infinity)
                                .frame(height: 14)
                                .opacity(day > today ? 0.35 : 1)
                                .help(n == 0 ? "" : "\(n) palabras")
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Keycap("fn"); Keycap("fn")
            Text("habla").font(.system(size: 12)).foregroundStyle(.secondary)
            Keycap("fn")
            Spacer()
            Link("Hecho por Martín Urbano · Open Source Everything", destination: Settings.instagram)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}

private struct Keycap: View {
    let label: String
    init(_ label: String) { self.label = label }
    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .frame(width: 28, height: 24)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Theme.line))
    }
}

final class HomeWindow: NSWindow {
    init(store: StatsStore, engine: Engine) {
        let host = NSHostingController(rootView: HomeView(store: store, engine: engine))
        super.init(contentRect: NSRect(x: 0, y: 0, width: 720, height: 640),
                   styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView], backing: .buffered, defer: false)
        contentViewController = host
        title = "Speak Away"
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = Theme.backgroundNS
        isReleasedWhenClosed = false
        setContentSize(host.view.fittingSize)
        center()
    }
}
