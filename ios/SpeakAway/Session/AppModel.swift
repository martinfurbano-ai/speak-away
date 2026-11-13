import SwiftUI
import SpeakAwayCore

/// What the app shows and what opens it. The keyboard opens the app with `speakaway://session/start` to begin a
/// session and with `speakaway://setup` when it needs Full Access. In preview mode (`--preview <screen>`) everything
/// comes from fictional sample data in a temporary folder, so the real files are never touched.
@MainActor
final class AppModel: ObservableObject {
    enum Tab: Hashable {
        case home, history, notes, voice, settings
    }

    enum NotesSegment: Hashable {
        case pad, meetings
    }

    enum NotesRoute: Hashable {
        case note(UUID)
        case meeting(UUID)
        /// The meeting being recorded.
        case recording
    }

    enum VoiceRoute: Hashable {
        case dictionary, snippets, style
    }

    /// A screen that covers the tabs.
    enum Cover: Identifiable, Equatable {
        case listening
        case onboarding(OnboardingStep)

        var id: String {
            switch self {
            case .listening: return "listening"
            case .onboarding: return "onboarding"
            }
        }
    }

    @Published var tab: Tab = .home
    @Published var notesSegment: NotesSegment = .pad
    @Published var notesPath: [NotesRoute] = []
    @Published var voicePath: [VoiceRoute] = []
    @Published var cover: Cover?

    let session: SessionController
    let store: PhoneStore
    let noteDictation: NoteDictation
    let recorder: MeetingRecorder
    /// Set when the app was launched with `--preview`.
    let preview: PreviewRequest?
    /// The folder of the sample data in preview mode.
    let previewFolder: URL?

    private static let onboardingKey = "onboardingCompleted"

    init(session: SessionController? = nil, store: PhoneStore? = nil) {
        let store = store ?? PhoneStore()
        let session = session ?? SessionController()
        self.store = store
        self.session = session
        self.noteDictation = NoteDictation(session: session, store: store)
        self.recorder = MeetingRecorder(session: session, store: store)
        self.preview = nil
        self.previewFolder = nil
        if !UserDefaults.standard.bool(forKey: Self.onboardingKey) { cover = .onboarding(.welcome) }
    }

    /// A model that shows one screen with sample data, for screenshots.
    init(preview request: PreviewRequest) {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("speakaway-preview-\(UUID().uuidString)", isDirectory: true)
        let facts = SampleData.write(into: folder)
        let store = PhoneStore(folder: folder)
        let session = SessionController(files: SessionFiles(folder: folder), stores: SharedStores(folder: folder),
                                        makeInput: { FileInput(url: URL(fileURLWithPath: "/dev/null")) })
        self.store = store
        self.session = session
        self.noteDictation = NoteDictation(session: session, store: store)
        self.recorder = MeetingRecorder(session: session, store: store)
        self.preview = request
        self.previewFolder = folder

        session.showPreview(state: .ready(until: Date().addingTimeInterval(12 * 60)),
                            sessionEnd: Date().addingTimeInterval(12 * 60), live: true)
        switch request.screen {
        case .home: tab = .home
        case .history: tab = .history
        case .notes: tab = .notes
        case .meetings:
            tab = .notes
            notesSegment = .meetings
        case .meetingRecording:
            tab = .notes
            notesSegment = .meetings
            notesPath = [.recording]
            session.showPreview(state: .meeting(paused: false), sessionEnd: nil, live: false)
            recorder.showPreview(SampleData.recording(spanish: UILanguage.isSpanish))
        case .meetingDetail:
            tab = .notes
            notesSegment = .meetings
            notesPath = [.meeting(facts.meetingID)]
        case .voice: tab = .voice
        case .dictionary:
            tab = .voice
            voicePath = [.dictionary]
        case .snippets:
            tab = .voice
            voicePath = [.snippets]
        case .style:
            tab = .voice
            voicePath = [.style]
        case .settings: tab = .settings
        case .onboarding1, .onboarding2, .onboarding3, .onboarding4, .onboarding5, .session, .keyboard,
             .keyboardRecording, .keyboardResult:
            break   // the root view shows these directly
        }
    }

    /// The light or dark look asked for with `--appearance`; `nil` follows the system.
    var forcedScheme: ColorScheme? {
        switch preview?.appearance {
        case .light?: return .light
        case .dark?: return .dark
        case nil: return nil
        }
    }

    func open(_ url: URL) {
        guard preview == nil, url.scheme?.lowercased() == SessionChannel.urlScheme else { return }
        switch url.host?.lowercased() {
        case "session":
            if recorder.isActive {
                // The microphone belongs to the meeting: show it instead of asking for a dictation session.
                cover = nil
                tab = .notes
                notesSegment = .meetings
                notesPath = [.recording]
            } else {
                cover = .listening
                Task { await session.startSession() }
            }
        case "setup":
            cover = .onboarding(.keyboard)
        default:
            break
        }
    }

    /// Starts a meeting and shows its screen, or just shows it when one is already going.
    func startMeetingRecording() {
        tab = .notes
        notesSegment = .meetings
        if !recorder.isActive { recorder.begin() }
        notesPath = [.recording]
    }

    /// The meeting was saved: its note replaces the recording screen. `nil`: nothing was kept, back to the list.
    func openSavedMeeting(_ id: UUID?) {
        notesPath = id.map { [.meeting($0)] } ?? []
    }

    /// The first-launch tour was finished (or skipped to the end) at least once.
    var onboardingCompleted: Bool { UserDefaults.standard.bool(forKey: Self.onboardingKey) }

    /// Closes the tour. The preview mode never writes the flag, so a screenshot run leaves the real app as it was.
    func finishOnboarding() {
        if preview == nil { UserDefaults.standard.set(true, forKey: Self.onboardingKey) }
        cover = nil
    }

    func showOnboardingAgain() {
        cover = .onboarding(.welcome)
    }
}
