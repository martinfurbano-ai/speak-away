import SwiftUI
import SpeakAwayCore

/// The first launch: five short screens (welcome, permissions, the speech model, the keyboard, a try). It comes back
/// from Settings > Keyboard, and the keyboard opens it at the keyboard step when Full Access is missing.
/// In preview mode nothing here asks for a permission or fetches a model: the screens show sample states.
struct OnboardingFlow: View {
    let start: OnboardingStep

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var session: SessionController
    @EnvironmentObject private var store: PhoneStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var step: OnboardingStep
    @State private var micAllowed = false
    @State private var micDenied = false
    @State private var speechAllowed = false
    @State private var speechDenied = false
    @State private var asking = false
    @State private var modelState: SpeechModelState = .unknown
    /// Whether the speech model was already on the phone when the tour began, which decides if its screen is shown.
    @State private var modelInstalledAtStart: Bool?
    @State private var languageName = ""
    @State private var downloadProblem: String?
    @State private var trial = ""

    init(start: OnboardingStep) {
        self.start = start
        _step = State(initialValue: start)
    }

    private var installedAtStart: Bool { modelInstalledAtStart ?? false }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                content
                    .id(step)
                    .transition(.opacity)
                    .frame(maxWidth: 520)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            footer
        }
        .screenBackground()
        .task(id: step) { await arrive(at: step) }
        .onChange(of: start) { _, new in step = new }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, model.preview == nil { refreshPermissions() }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Group {
                if let previous = Onboarding.previous(before: step, modelInstalled: installedAtStart) {
                    Button { go(to: previous) } label: { Image(systemName: "chevron.backward").font(.headline) }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .accessibilityLabel("Back")
                } else {
                    Color.clear
                }
            }
            .frame(width: 44, height: 44)
            Spacer()
            dots
            Spacer()
            Group {
                if canClose {
                    Button { model.cover = nil } label: { Image(systemName: "xmark").font(.headline) }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .accessibilityLabel("Close")
                } else {
                    Color.clear
                }
            }
            .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// The tour can be closed at any step once it has been finished before (it was reopened from Settings).
    private var canClose: Bool { model.preview == nil && model.onboardingCompleted }

    private var dots: some View {
        let position = Onboarding.position(of: step, modelInstalled: installedAtStart)
        return HStack(spacing: 8) {
            ForEach(1...position.total, id: \.self) { index in
                Capsule()
                    .fill(index == position.index ? Theme.accent : Theme.track)
                    .frame(width: index == position.index ? 22 : 8, height: 8)
            }
        }
        .animation(.snappy, value: position.index)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Step \(position.index) of \(position.total)"))
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 12) {
            Button(action: primaryAction) { PrimaryButtonLabel(title: primaryTitle) }
                .buttonStyle(.glassProminent)
                .disabled(primaryDisabled)
            if Onboarding.canSkip(step, micAllowed: micAllowed, model: modelState) {
                Button { goNext() } label: { PrimaryButtonLabel(title: "Not now") }
                    .buttonStyle(.glass)
            }
        }
        .controlSize(.large)
        .frame(maxWidth: 520)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
    }

    private var primaryTitle: LocalizedStringKey {
        switch step {
        case .welcome:
            return "Get started"
        case .permissions:
            if micAllowed { return "Continue" }
            return micDenied ? "Open Settings" : "Allow access"
        case .speechModel:
            switch modelState {
            case .installed: return "Continue"
            case .downloading: return "Downloading"
            case .failed: return "Try again"
            case .unknown, .missing: return "Download"
            }
        case .keyboard:
            return "Continue"
        case .tryIt:
            return "Start dictating"
        }
    }

    private var primaryDisabled: Bool {
        if asking { return true }
        guard step == .speechModel else { return false }
        switch modelState {
        case .unknown, .downloading: return true
        case .missing, .installed, .failed: return false
        }
    }

    private func primaryAction() {
        switch step {
        case .permissions:
            if micAllowed {
                goNext()
            } else if micDenied {
                SettingsLink.open()
            } else {
                Task { await askPermissions() }
            }
        case .speechModel:
            if modelState == .installed { goNext() } else { Task { await downloadModel() } }
        case .welcome, .keyboard, .tryIt:
            goNext()
        }
    }

    // MARK: Moving between screens

    private func go(to next: OnboardingStep) {
        withAnimation(.snappy) { step = next }
    }

    private func goNext() {
        if let next = Onboarding.next(after: step, modelInstalled: installedAtStart) {
            go(to: next)
        } else {
            model.finishOnboarding()
        }
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        switch step {
        case .welcome: welcome
        case .permissions: permissions
        case .speechModel: speechModel
        case .keyboard: keyboard
        case .tryIt: tryIt
        }
    }

    private var welcome: some View {
        VStack(spacing: 28) {
            BubbleView()
                .frame(width: 132, height: 115)
                .padding(.top, 24)
            VStack(spacing: 10) {
                Text("Speak. It writes itself.")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                Text("Dictate in any app with the Speak Away keyboard. It all happens on your iPhone, with no account and no key.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: 16) {
                Highlight(icon: "mic.fill", text: "Tap the mic and talk")
                Highlight(icon: "text.cursor", text: "The text lands where you are typing")
                Highlight(icon: "lock.fill", text: "Nothing you say leaves your iPhone")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var permissions: some View {
        VStack(spacing: 24) {
            StepHeading(icon: "mic.fill", title: "Let Speak Away listen",
                        detail: "Two permissions. Both are used only on your iPhone.")
            Card {
                VStack(alignment: .leading, spacing: 18) {
                    PermissionRow(icon: "mic.fill", title: "Microphone", detail: "To hear you when you dictate.",
                                  status: micAllowed ? .allowed : (micDenied ? .off : .pending))
                    Divider()
                    PermissionRow(icon: "waveform", title: "Speech recognition",
                                  detail: "So your iPhone can turn your voice into text.",
                                  status: speechAllowed ? .allowed : (speechDenied ? .off : .pending))
                }
            }
            if micDenied && !micAllowed {
                SessionProblem(message: String(localized: "Microphone access is off. Allow it in Settings to dictate."),
                               needsSettings: false)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var speechModel: some View {
        VStack(spacing: 24) {
            StepHeading(icon: "waveform", title: "Get the speech model",
                        detail: "Your iPhone needs a small speech model for your language. It downloads once and then works without internet.")
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(languageName).font(.headline)
                            Text("Speech model").font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        modelBadge
                    }
                    if case .downloading(let fraction) = modelState {
                        SpeechModelProgress(fraction: fraction)
                    }
                    if let downloadProblem {
                        SessionProblem(message: downloadProblem, needsSettings: false)
                    }
                }
            }
        }
    }

    @ViewBuilder private var modelBadge: some View {
        switch modelState {
        case .installed:
            Label("Ready", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.subheadline.weight(.medium))
        case .downloading:
            ProgressView()
        case .failed:
            Label("Download failed", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.subheadline.weight(.medium))
        case .missing:
            Text("Not downloaded yet").font(.subheadline).foregroundStyle(.secondary)
        case .unknown:
            ProgressView()
        }
    }

    private var keyboard: some View {
        VStack(spacing: 24) {
            StepHeading(icon: "keyboard", title: "Add the keyboard", detail: "Three steps in the Settings app.")
            Card { KeyboardSteps() }
            Button { SettingsLink.open() } label: { PrimaryButtonLabel(title: "Open Settings", systemImage: "gearshape") }
                .buttonStyle(.glass)
                .controlSize(.large)
        }
    }

    private var tryIt: some View {
        VStack(spacing: 24) {
            StepHeading(icon: "text.cursor", title: "Try it",
                        detail: "Tap the field, switch to the Speak Away keyboard with the globe key, and tap its mic.")
            Card(padding: 14) {
                TextField("Tap here and dictate", text: $trial, axis: .vertical)
                    .lineLimit(4...8)
                    .frame(minHeight: 96, alignment: .topLeading)
            }
            VStack(spacing: 12) {
                LiveSessionPill()
                if let problem = session.problem {
                    SessionProblem(message: problem, needsSettings: session.problemNeedsSettings)
                }
                if !session.live {
                    Button { Task { await session.startSession() } } label: {
                        PrimaryButtonLabel(title: "Start session", systemImage: "play.fill")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                }
            }
        }
    }

    // MARK: Permissions

    private func refreshPermissions() {
        micAllowed = MicPermission.isAllowed
        micDenied = MicPermission.isDenied
        speechAllowed = SpeechPermission.isAllowed
        speechDenied = SpeechPermission.isDenied
    }

    /// Asks for the microphone, then for speech recognition. Only the microphone is required to go on.
    private func askPermissions() async {
        guard model.preview == nil else { return }
        asking = true
        defer { asking = false }
        micAllowed = await MicPermission.request()
        micDenied = MicPermission.isDenied
        speechAllowed = await SpeechPermission.request()
        speechDenied = SpeechPermission.isDenied
    }

    // MARK: Speech model

    /// What each screen needs when it appears: the real permission answers and the state of the speech model, or
    /// sample states in preview mode.
    private func arrive(at step: OnboardingStep) async {
        guard model.preview == nil else {
            showSampleState(for: step)
            return
        }
        refreshPermissions()
        if modelInstalledAtStart == nil { await checkModel() }
    }

    private var isDownloading: Bool {
        if case .downloading = modelState { return true }
        return false
    }

    private func checkModel() async {
        let speech = AppleSpeech()
        let locale = await speech.resolveLocale(setting: store.settings.language)
        languageName = Self.displayName(locale)
        let state = await AppleSpeech.modelState(for: locale)
        modelState = state
        modelInstalledAtStart = state == .installed
    }

    private func downloadModel() async {
        guard model.preview == nil, !isDownloading else { return }
        downloadProblem = nil
        modelState = .downloading(0)
        let speech = AppleSpeech()
        let locale = await speech.resolveLocale(setting: store.settings.language)
        languageName = Self.displayName(locale)
        do {
            try await speech.prepare(locale: locale) { fraction in
                Task { @MainActor in modelState = .downloading(fraction) }
            }
            modelState = .installed
        } catch {
            modelState = .failed
            downloadProblem = PhoneText.reason(for: error)
        }
    }

    private func showSampleState(for step: OnboardingStep) {
        modelInstalledAtStart = false
        languageName = Self.displayName(Locale(identifier: UILanguage.isSpanish ? "es-PA" : "en-US"))
        modelState = step == .speechModel ? .downloading(0.42) : .installed
    }

    /// "Español (Panamá)" in the language of the interface.
    private static func displayName(_ locale: Locale) -> String {
        let name = UILanguage.locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
        return name.prefix(1).uppercased() + String(name.dropFirst())
    }
}

// MARK: Pieces

/// The big icon, the title and the explanation at the top of a step.
private struct StepHeading: View {
    let icon: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.12)).frame(width: 72, height: 72)
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
            .accessibilityHidden(true)
            Text(title)
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
    }
}

/// One line of the welcome screen: an icon and what it promises.
private struct Highlight: View {
    let icon: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: 14) {
            IconTile(systemName: icon)
            Text(text).font(.body.weight(.medium))
        }
    }
}

private enum PermissionStatus {
    case pending, allowed, off
}

/// A permission with what it is for and where it stands.
private struct PermissionRow: View {
    let icon: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let status: PermissionStatus

    var body: some View {
        HStack(spacing: 14) {
            IconTile(systemName: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            switch status {
            case .allowed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
                    .accessibilityLabel("Allowed")
            case .off:
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Off")
            case .pending:
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Not asked yet")
            }
        }
        .accessibilityElement(children: .combine)
    }
}
