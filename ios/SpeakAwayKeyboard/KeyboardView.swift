import SwiftUI
import UIKit
import SpeakAwayCore

/// The keys. Black and white, Liquid Glass keys, the system's keyboard height. The mic is the largest key and sits in
/// the middle; the wand (Command Mode) and delete flank it; the bottom row has the globe (only when the system asks
/// for one), space and return. A thin top row has the style chip, a line of status, and Undo.
struct KeyboardView: View {
    @ObservedObject var model: KeyboardModel
    let inputController: UIInputViewController

    var body: some View {
        GlassEffectContainer(spacing: 4) {
            VStack(spacing: 8) {
                topRow
                if model.hasFullAccess {
                    mainRow
                } else {
                    accessNotice
                }
                bottomRow
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Rows

    private var topRow: some View {
        HStack(spacing: 8) {
            if model.hasFullAccess {
                Button { model.chipTapped() } label: {
                    Text(model.chipText)
                        .font(.footnote.weight(.medium))
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Writing style")
                .accessibilityValue(model.chipText)
            }
            Text(statusText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(statusText)
            if model.hasFullAccess {
                Button { model.undoTapped() } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 44, height: 30)
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(.plain)
                .disabled(!model.canUndo)
                .opacity(model.canUndo ? 1 : 0.4)
                .accessibilityLabel("Undo")
            }
        }
        .frame(height: 30)
    }

    private var mainRow: some View {
        HStack(spacing: 8) {
            Button { model.wandTapped() } label: {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 22, weight: .regular))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .glassEffect(wandActive ? .regular.tint(.primary).interactive() : .regular.interactive(),
                                 in: .rect(cornerRadius: 18))
                    .foregroundStyle(wandActive ? inverse : Color.primary)
            }
            .buttonStyle(.plain)
            .frame(width: 76)
            .accessibilityLabel("Command Mode")
            .accessibilityHint("Select text or write a sentence, tap, and say how to change it.")

            micKey
                .frame(maxWidth: .infinity)

            DeleteKey(model: model)
                .frame(width: 76)
        }
        .frame(maxHeight: .infinity)
    }

    private var bottomRow: some View {
        HStack(spacing: 8) {
            if model.needsGlobe {
                GlobeKey(controller: inputController)
                    .frame(width: 52, height: 44)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
            }
            Button { model.typeSpace() } label: {
                Text("space")
                    .font(.system(size: 16))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Space")
            Button { model.typeReturn() } label: {
                Text(model.returnTitle)
                    .font(.system(size: 16))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: 84)
                    .frame(maxHeight: .infinity)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.returnTitle == "return" ? "Return" : model.returnTitle)
        }
        .frame(height: 44)
    }

    /// Without Full Access the keyboard cannot talk to the app: say so once, and offer the way there.
    private var accessNotice: some View {
        VStack(spacing: 10) {
            Text("Dictation needs Full Access. Open Speak Away to see how to turn it on.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button { model.openSetup() } label: {
                Text("Open Speak Away")
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 20)
                    .frame(height: 40)
                    .glassEffect(.regular.interactive(), in: .capsule)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: The mic

    private var micKey: some View {
        let live = isRecording || isTranscribing
        return ZStack {
            if isRecording {
                LevelBars(phase: .listening, level: model.state.level, color: inverse, height: 52)
            } else if isTranscribing {
                LevelBars(phase: .thinking, color: inverse, height: 52)
            } else {
                Image(systemName: "mic.fill")
                    .font(.system(size: 38, weight: .semibold))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassEffect(live ? .regular.tint(.primary).interactive() : .regular.interactive(), in: .rect(cornerRadius: 26))
        .foregroundStyle(live ? inverse : Color.primary)
        .contentShape(RoundedRectangle(cornerRadius: 26))
        // Touch down starts or stops; letting go after a hold ends it (hold to talk). The rules live in `MicGesture`.
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in model.micPressed() }
                .onEnded { _ in model.micReleased() }
        )
        .accessibilityElement()
        .accessibilityLabel(micLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { model.micTapped() }
    }

    // MARK: State to words and colors

    private var isRecording: Bool {
        if case .recording = model.state { return true }
        return false
    }

    private var isTranscribing: Bool {
        if case .transcribing = model.state { return true }
        return false
    }

    private var wandActive: Bool { model.commandActive && (isRecording || isTranscribing) }

    /// The opposite of the primary color: white on black in light mode, black on white in dark mode.
    private var inverse: Color { Color(uiColor: .systemBackground) }

    private var micLabel: String {
        switch model.state {
        case .recording: return "Stop dictation"
        case .transcribing: return "Writing it down"
        case .idle: return "Dictate. Opens Speak Away to start."
        default: return "Dictate"
        }
    }

    private var statusText: String {
        if let hint = model.hint { return hint }
        guard model.hasFullAccess else { return "" }
        switch model.state {
        case .idle: return "Tap the mic. Speak Away opens, then swipe back."
        case .ready, .done: return ""
        case .recording: return model.commandActive ? "Say how to change the text" : "Listening"
        case .transcribing: return "Writing it down"
        case .failed(let reason): return reason
        }
    }
}

/// Delete: one press deletes one character; holding repeats, faster after a moment.
private struct DeleteKey: View {
    @ObservedObject var model: KeyboardModel
    @StateObject private var repeater = DeleteRepeater()

    var body: some View {
        Image(systemName: "delete.left")
            .font(.system(size: 22, weight: .regular))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
            .contentShape(RoundedRectangle(cornerRadius: 18))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in repeater.press { model.deleteOnce() } }
                    .onEnded { _ in repeater.release() }
            )
            .accessibilityElement()
            .accessibilityLabel("Delete")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { model.deleteOnce() }
            .onDisappear { repeater.release() }
    }
}

/// Runs the delete action once on touch down and, if the finger stays, again and again until it lifts.
@MainActor
private final class DeleteRepeater: ObservableObject {
    private var timer: Timer?
    private var down = false

    func press(_ action: @escaping () -> Void) {
        guard !down else { return }
        down = true
        action()
        // Waits before repeating, so a plain press deletes exactly one character.
        timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.down else { return }
                action()
                self.timer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
                    MainActor.assumeIsolated {
                        guard let self, self.down else { return }
                        action()
                    }
                }
            }
        }
    }

    func release() {
        down = false
        timer?.invalidate()
        timer = nil
    }
}

/// The system's own next-keyboard key. It must be a UIKit button wired to `handleInputModeList`, which is what
/// gives it the long-press list of keyboards.
private struct GlobeKey: UIViewRepresentable {
    let controller: UIInputViewController

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "globe"), for: .normal)
        button.tintColor = .label
        button.accessibilityLabel = "Next keyboard"
        button.addTarget(controller, action: #selector(UIInputViewController.handleInputModeList(from:with:)), for: .allTouchEvents)
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {}
}
