import AVFoundation
import SwiftUI
import SpeakAwayBrain
import SpeakAwayCore

/// Ajustes: language, how long a session lasts, the microphone, the text helpers, sounds, the keyboard and privacy.
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var store: PhoneStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var inputs: [MicrophoneChoice] = []
    @State private var brain: BrainAvailability = .available

    private static let privacyURL = URL(string: "https://speakaway.heliospanama.com/privacidad/")!
    private static let instagramURL = URL(string: "https://instagram.com/opensourceeverything")!

    var body: some View {
        NavigationStack {
            List {
                dictationSection
                textSection
                feedbackSection
                keyboardSection
                privacySection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .appList()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .task { refresh() }
            .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { _ in
                refresh()
            }
        }
    }

    // MARK: Sections

    private var dictationSection: some View {
        Section {
            Picker(selection: binding(\.language)) {
                Text("Same as the system").tag("auto")
                Text(verbatim: "Español").tag("es")
                Text(verbatim: "English").tag("en")
            } label: {
                Label("Language", systemImage: "globe")
            }
            .cardRow()

            Picker(selection: binding(\.sessionLength)) {
                ForEach(SessionLength.allCases, id: \.self) { length in
                    Text(PhoneText.title(for: length)).tag(length)
                }
            } label: {
                Label("Session length", systemImage: "timer")
            }
            .cardRow()

            Picker(selection: microphone) {
                Text("Automatic").tag("")
                ForEach(inputs) { input in
                    Text(verbatim: input.name).tag(input.uid)
                }
            } label: {
                Label("Microphone", systemImage: "mic")
            }
            .cardRow()
        } header: {
            Text("Dictation")
        } footer: {
            Text("A session keeps the microphone ready so the keyboard can start dictating at once.")
        }
    }

    private var textSection: some View {
        Section {
            SettingToggle(title: "Auto-edits", icon: "wand.and.stars", isOn: binding(\.autoEdit)) {
                Text("Removes “um” and “uh”, and “at 2, no, make it 3” becomes “at 3”.")
            }
            .cardRow()

            SettingToggle(title: "Brain", icon: "sparkles",
                          isOn: Binding(get: { store.settings.polish && brain.isUsable },
                                        set: { value in store.updateSettings { $0.polish = value } })) {
                VStack(alignment: .leading, spacing: 4) {
                    if brain.isUsable {
                        Text("Tidies up the sentence on your iPhone before it is written. A bit slower.")
                    }
                    Text(PhoneText.brainSettingsDetail(brain))
                }
            }
            .disabled(!brain.isUsable)
            .cardRow()
        } header: {
            Text("Text")
        }
    }

    private var feedbackSection: some View {
        Section {
            SettingToggle(title: "Sounds", icon: "speaker.wave.2", isOn: binding(\.sounds)) {
                Text("Short tones when a session starts and ends.")
            }
            .cardRow()

            SettingToggle(title: "Vibration", icon: "iphone.radiowaves.left.and.right", isOn: binding(\.haptics)) {
                Text("A light tap when you start, stop or copy.")
            }
            .cardRow()
            .onChange(of: store.settings.haptics) { _, on in Haptics.tap(enabled: on) }
        } header: {
            Text("Feedback")
        }
    }

    private var keyboardSection: some View {
        Section {
            NavigationLink {
                KeyboardSetupPage()
            } label: {
                HStack(spacing: 14) {
                    IconTile(systemName: "keyboard")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Keyboard").font(.headline)
                        Text("Add it and allow Full Access").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
            .cardRow()
        }
    }

    private var privacySection: some View {
        Section {
            Label {
                Text("Nothing you dictate leaves your iPhone.")
            } icon: {
                Image(systemName: "lock.fill").foregroundStyle(Theme.accent)
            }
            .cardRow()

            Link(destination: Self.privacyURL) {
                HStack {
                    Label("Privacy policy", systemImage: "hand.raised")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .cardRow()
        } header: {
            Text("Privacy")
        } footer: {
            Text("The speech engine and the brain run on your iPhone. There is no account, no key and no server.")
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(verbatim: Self.version).foregroundStyle(.secondary)
            }
            .cardRow()

            Link(destination: Self.instagramURL) {
                Text("Made by Martín Urbano for Open Source Everything")
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)
        }
    }

    // MARK: Bindings

    /// A setting as a binding: reading it, and saving a new value when the person changes it.
    private func binding<Value>(_ keyPath: WritableKeyPath<PhoneSettings, Value>) -> Binding<Value> {
        Binding(get: { store.settings[keyPath: keyPath] },
                set: { value in store.updateSettings { $0[keyPath: keyPath] = value } })
    }

    /// The saved microphone, or Automatic when that one is not plugged in any more.
    private var microphone: Binding<String> {
        Binding(get: {
            let saved = store.settings.microphone
            return MicrophoneChoices.isConnected(uid: saved, among: inputs) ? saved : ""
        }, set: { value in store.updateSettings { $0.microphone = value } })
    }

    // MARK: Data

    private func refresh() {
        if model.preview == nil {
            inputs = MicrophoneChoices.current()
            brain = LocalBrain.availability
        } else {
            inputs = SampleData.microphones
            brain = .available
        }
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }
}

/// A switch with an icon, a title and a few grey lines under it.
private struct SettingToggle<Detail: View>: View {
    let title: LocalizedStringKey
    let icon: String
    @Binding var isOn: Bool
    @ViewBuilder var detail: () -> Detail

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: icon)
                detail()
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: Keyboard setup

/// Settings > Keyboard: the steps to add the keyboard and allow Full Access, and the way back to the first-launch tour.
struct KeyboardSetupPage: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Card { KeyboardSteps() }
                VStack(spacing: 12) {
                    Button { SettingsLink.open() } label: {
                        PrimaryButtonLabel(title: "Open Settings", systemImage: "gearshape")
                    }
                    .buttonStyle(.glassProminent)
                    Button { model.showOnboardingAgain() } label: {
                        PrimaryButtonLabel(title: "Show the setup again", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.glass)
                }
                .controlSize(.large)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("Keyboard")
        .navigationBarTitleDisplayMode(.inline)
        .screenBackground()
    }
}

/// The three steps that turn the keyboard on, in the words of the Settings app. Used in Settings and in the tour.
struct KeyboardSteps: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            NumberedStep(number: 1, text: "Open Settings, then General, Keyboard, Keyboards, Add New Keyboard, and pick Speak Away.")
            NumberedStep(number: 2, text: "Tap Speak Away in that list and turn on Allow Full Access. The keyboard needs it to talk to this app. Your voice and text stay on this iPhone.")
            NumberedStep(number: 3, text: "In any app, hold the globe key and choose Speak Away. Tap its mic to dictate.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
