import AVFoundation
import SwiftUI
import SpeakAwayBrain
import SpeakAwayCore

/// The app's few screens. The real ones (history, dictionary, settings) come in the next step; for now
/// there is the screen the keyboard opens, a home screen and the setup steps.
struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            switch model.screen {
            case .home: HomeView()
            case .listening: ListeningView()
            case .setup: SetupView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.screen)
    }
}

/// What the screen shows about the session, in words.
enum SessionCaption {
    static func text(for state: SessionState, now: Date = Date()) -> String {
        switch state {
        case .idle: return "No session running"
        case .ready(let until):
            guard let until else { return "Ready until you stop it" }
            let minutes = max(1, Int((SessionPolicy.remaining(until: until, at: now) ?? 0) / 60.0 + 0.5))
            return "Ready for \(minutes) more \(minutes == 1 ? "minute" : "minutes")"
        case .recording: return "Listening"
        case .transcribing: return "Writing it down"
        case .done: return "Done"
        case .failed(let reason): return reason
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var session: SessionController

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            LevelBars(phase: .idle, height: 64)
            VStack(spacing: 6) {
                Text("Speak Away")
                    .font(.largeTitle.weight(.semibold))
                Text(SessionCaption.text(for: session.state))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 12) {
                Button {
                    model.screen = .listening
                    Task { await session.startSession() }
                } label: {
                    Text(session.isActive ? "Show session" : "Start a session").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                Button {
                    model.screen = .setup
                } label: {
                    Text("Set up the keyboard").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
            .controlSize(.large)
            .tint(.primary)
        }
        .padding(24)
    }
}

struct ListeningView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var session: SessionController

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            LevelBars(phase: barPhase, level: session.state.level, height: 96)
            VStack(spacing: 8) {
                Text(headline)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(SessionCaption.text(for: session.state))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let progress = session.speechProgress {
                    ProgressView(value: progress) {
                        Text("Getting the speech model ready").font(.footnote)
                    }
                    .padding(.top, 8)
                }
                if let problem = session.problem {
                    Text(problem)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if problem.contains("Settings") {
                        Button("Open Settings") { SettingsLink.open() }
                            .buttonStyle(.glass)
                    }
                }
            }
            Spacer()
            VStack(spacing: 12) {
                if session.isActive {
                    Button {
                        session.endSession()
                    } label: {
                        Text("Stop").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                } else {
                    Button {
                        Task { await session.startSession() }
                    } label: {
                        Text("Try again").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                }
                Button("Done") { model.screen = .home }
                    .buttonStyle(.glass)
            }
            .controlSize(.large)
            .tint(.primary)
        }
        .padding(24)
    }

    private var headline: String {
        if !session.isActive { return "Speak Away is not listening." }
        if session.speechProgress != nil { return "Getting the speech model ready. Stay here until it finishes." }
        return "Speak Away is listening. Swipe back to keep typing."
    }

    private var barPhase: BubbleMotion.Phase {
        switch session.state {
        case .recording: return .listening
        case .transcribing: return .thinking
        default: return .idle
        }
    }
}

struct SetupView: View {
    @EnvironmentObject private var model: AppModel
    @State private var micAllowed: Bool?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Set up the keyboard")
                    .font(.largeTitle.weight(.semibold))
                step(1, "Open Settings, then General, Keyboard, Keyboards, Add New Keyboard, and pick Speak Away.")
                step(2, "Tap Speak Away in that list and turn on Allow Full Access. The keyboard needs it to talk to this app. Your voice and text stay on this iPhone.")
                step(3, "Allow the microphone so Speak Away can listen when you dictate.")
                VStack(spacing: 12) {
                    Button { SettingsLink.open() } label: { Text("Open Settings").frame(maxWidth: .infinity) }
                        .buttonStyle(.glassProminent)
                    Button {
                        Task { micAllowed = await MicPermission.request() }
                    } label: {
                        Text(micLabel).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    Button("Done") { model.screen = .home }
                        .buttonStyle(.glass)
                }
                .controlSize(.large)
                .tint(.primary)
            }
            .padding(24)
        }
    }

    private var micLabel: String {
        switch micAllowed {
        case true?: return "Microphone allowed"
        case false?: return "Microphone is off, open Settings"
        case nil: return "Allow the microphone"
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.headline)
                .frame(width: 30, height: 30)
                .glassEffect(.regular, in: .circle)
            Text(text).font(.body)
        }
    }
}

enum SettingsLink {
    static func open() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
}

enum MicPermission {
    static func request() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return true
        case .denied: return false
        default: return await AVAudioApplication.requestRecordPermission()
        }
    }
}
