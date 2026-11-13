import SwiftUI
import SpeakAwayCore

/// Inicio: the greeting, the session, the streak, the numbers, the last weeks and the last dictations.
struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var store: PhoneStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HomeHeader()
                    SessionCard()
                    StreakCard(stats: store.stats, today: DayKey(Date()))
                    NumbersSection(stats: store.stats)
                    ActivityCard(stats: store.stats, today: DayKey(Date()))
                    LatestDictations(items: Array(store.history.sorted { $0.date > $1.date }.prefix(3))) {
                        model.tab = .history
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: Header

private struct HomeHeader: View {
    var body: some View {
        HStack(spacing: 14) {
            BubbleView().frame(width: 52, height: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting).font(.title.weight(.bold))
                Text("Tap the mic on the Speak Away keyboard to dictate in any app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .accessibilityElement(children: .combine)
    }

    private var greeting: LocalizedStringKey {
        switch Greeting.at(Date()) {
        case .morning: return "Good morning"
        case .afternoon: return "Good afternoon"
        case .evening: return "Good evening"
        }
    }
}

// MARK: Session

private struct SessionCard: View {
    @EnvironmentObject private var session: SessionController
    @EnvironmentObject private var store: PhoneStore

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                LiveSessionPill()
                if let progress = session.speechProgress {
                    SpeechModelProgress(fraction: progress)
                }
                if let problem = session.problem {
                    SessionProblem(message: problem, needsSettings: session.problemNeedsSettings)
                }
                if session.live {
                    EndSessionButton(action: toggle)
                } else {
                    Button(action: toggle) {
                        PrimaryButtonLabel(title: "Start session", systemImage: "mic.fill")
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                }
            }
        }
    }

    private func toggle() {
        Haptics.tap(enabled: store.settings.haptics)
        if session.live {
            session.endSession()
        } else {
            Task { await session.startSession() }
        }
    }
}

// MARK: Streak

private struct StreakCard: View {
    let stats: UsageStats
    let today: DayKey
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 46

    var body: some View {
        let streak = stats.currentStreak(today: today)
        let dictatedToday = stats.days[today.ordinal] != nil
        let unit: LocalizedStringKey = streak == 1 ? "day in a row" : "days in a row"
        Card {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 16) {
                    flame(active: streak > 0)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(verbatim: "\(streak)")
                                .font(.system(size: numberSize, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            Text(unit).font(.headline)
                        }
                        Text(note(streak: streak, dictatedToday: dictatedToday, best: stats.bestStreak))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
                week
            }
        }
    }

    private func flame(active: Bool) -> some View {
        ZStack {
            Circle()
                .fill(Theme.accent.opacity(active ? 0.14 : 0.07))
                .frame(width: 64, height: 64)
            Image(systemName: "flame.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(active
                    ? AnyShapeStyle(LinearGradient(colors: [Color(red: 1, green: 0.62, blue: 0.3), Theme.accent],
                                                   startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(Color.secondary.opacity(0.5)))
        }
        .accessibilityHidden(true)
    }

    private func note(streak: Int, dictatedToday: Bool, best: Int) -> LocalizedStringKey {
        switch StreakNote.make(streak: streak, dictatedToday: dictatedToday, best: best) {
        case .start: return "Dictate something today to start your streak."
        case .keep: return "Dictate something today to keep it going."
        case .best(let days): return "Your best streak: \(days) days."
        case .record: return "This is your best streak. Keep it up."
        }
    }

    /// One dot per day of this week, Monday first, with a red check on the days with dictation.
    private var week: some View {
        let letters = UILanguage.isSpanish ? ["L", "M", "M", "J", "V", "S", "D"] : ["M", "T", "W", "T", "F", "S", "S"]
        return HStack(spacing: 0) {
            ForEach(StreakWeek.days(containing: today, stats: stats)) { day in
                VStack(spacing: 6) {
                    Text(letters[day.index]).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    ZStack {
                        Circle().fill(day.done ? Theme.accent : Theme.track)
                        if day.done {
                            Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy)).foregroundStyle(.white)
                        }
                        if day.isToday && !day.done {
                            Circle().strokeBorder(Theme.accent, lineWidth: 1.5)
                        }
                    }
                    .frame(width: 28, height: 28)
                    .opacity(day.isFuture ? 0.45 : 1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: Numbers

private struct NumbersSection: View {
    let stats: UsageStats

    var body: some View {
        let milestone = Milestone.next(after: stats.totalWords)
        VStack(spacing: 16) {
            StatCard(icon: "text.word.spacing", value: number(stats.totalWords), label: "Words dictated") {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressBar(fraction: milestone.progress)
                    Text("Goal: \(number(milestone.target))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(alignment: .top, spacing: 16) {
                StatCard(icon: "speedometer", value: number(stats.wordsPerMinute), label: "Words per minute") {
                    Text("Typing: about 40").font(.footnote).foregroundStyle(.secondary)
                }
                StatCard(icon: "clock.arrow.circlepath", value: StatFormat.timeSaved(minutes: stats.minutesSaved()),
                         label: "Time saved") {
                    dictations
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var dictations: some View {
        let count = stats.totalSessions
        Group {
            if count == 1 {
                Text("1 dictation")
            } else {
                Text("\(number(count)) dictations")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private func number(_ value: Int) -> String {
        StatFormat.number(value, locale: UILanguage.locale)
    }
}

// MARK: Activity

private struct ActivityCard: View {
    let stats: UsageStats
    let today: DayKey
    private let weeks = 16
    /// The gap between squares as a share of a square, so the map keeps its shape at any width.
    private let gap: CGFloat = 0.18

    var body: some View {
        let grid = ActivityGrid.make(stats: stats, today: today, weeks: weeks)
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Activity").font(.headline)
                    Spacer()
                    Text("Last \(weeks) weeks").font(.footnote).foregroundStyle(.secondary)
                }
                Canvas { context, size in
                    draw(grid, in: &context, size: size)
                }
                .aspectRatio(aspect, contentMode: .fit)
                .accessibilityLabel("Activity over the last \(weeks) weeks")
            }
        }
    }

    /// Width over height of the whole map.
    private var aspect: CGFloat {
        let columns = CGFloat(weeks)
        return (columns + (columns - 1) * gap) / (7 + 6 * gap)
    }

    private func draw(_ grid: ActivityGrid, in context: inout GraphicsContext, size: CGSize) {
        let columns = CGFloat(grid.weeks.count)
        let cell = size.width / (columns + (columns - 1) * gap)
        let step = cell * (1 + gap)
        for (w, week) in grid.weeks.enumerated() {
            for (d, entry) in week.enumerated() {
                let rect = CGRect(x: CGFloat(w) * step, y: CGFloat(d) * step, width: cell, height: cell)
                let shape = Path(roundedRect: rect, cornerRadius: cell * 0.28, style: .continuous)
                let color = entry.words == 0 ? Theme.track : Theme.accent.opacity(entry.level)
                context.fill(shape, with: .color(color.opacity(entry.isFuture ? 0.35 : 1)))
            }
        }
    }
}

// MARK: Latest dictations

private struct LatestDictations: View {
    let items: [HistoryItem]
    let seeAll: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Latest dictations").font(.headline)
                    Spacer()
                    if !items.isEmpty {
                        Button("See all", action: seeAll).font(.subheadline)
                    }
                }
                if items.isEmpty {
                    Text("Nothing dictated yet. What you say with the keyboard shows up here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Divider() }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.text).font(.body).lineLimit(2)
                            Text(item.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }
}
