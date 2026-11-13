import SwiftUI
import SpeakAwayCore

/// The app: five tabs like the Mac sidebar, and the screens that cover them (the session the keyboard opens, and the
/// tour of the first launch). In preview mode (`--preview <screen>`) it shows that one screen with sample data.
struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var session: SessionController
    @EnvironmentObject private var store: PhoneStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        content
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { store.reload() }
            }
            .onChange(of: session.state) { _, state in
                // A finished dictation changes the history and the numbers.
                if case .done = state { store.reload() }
            }
    }

    @ViewBuilder private var content: some View {
        if let step = model.preview?.screen.onboardingStep {
            OnboardingFlow(start: step)
        } else if let screen = model.preview?.screen, let moment = Self.keyboardMoment(for: screen) {
            KeyboardPreviewView(moment: moment, folder: model.previewFolder ?? FileManager.default.temporaryDirectory)
        } else if model.preview?.screen == .session {
            ListeningView(dismissable: false)
        } else {
            tabs
        }
    }

    private var tabs: some View {
        TabView(selection: $model.tab) {
            Tab("Home", systemImage: "house", value: AppModel.Tab.home) {
                HomeView()
            }
            Tab("History", systemImage: "clock", value: AppModel.Tab.history) {
                HistoryView()
            }
            Tab("Notes", systemImage: "note.text", value: AppModel.Tab.notes) {
                NotesView()
            }
            Tab("Your voice", systemImage: "person.wave.2", value: AppModel.Tab.voice) {
                VoiceView()
            }
            Tab("Settings", systemImage: "gearshape", value: AppModel.Tab.settings) {
                SettingsView()
            }
        }
        .fullScreenCover(item: $model.cover) { cover in
            switch cover {
            case .listening:
                ListeningView()
            case .onboarding(let step):
                OnboardingFlow(start: step)
            }
        }
    }

    private static func keyboardMoment(for screen: PreviewScreen) -> KeyboardPreviewView.Moment? {
        switch screen {
        case .keyboard: return .ready
        case .keyboardRecording: return .recording
        case .keyboardResult: return .result
        default: return nil
        }
    }
}
