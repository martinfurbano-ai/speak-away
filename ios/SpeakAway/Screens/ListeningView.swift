import SwiftUI
import SpeakAwayCore

/// The screen the keyboard opens when it needs a session: the microphone is on, so the person swipes back to the
/// app they were typing in. It also shows the speech model being fetched the first time, and what went wrong.
struct ListeningView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var session: SessionController
    @EnvironmentObject private var store: PhoneStore
    /// False in the preview mode, where this screen is the whole app and there is nothing to go back to.
    var dismissable = true

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            VStack(spacing: 26) {
                mark
                VStack(spacing: 10) {
                    Text(headline)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    if isListening {
                        Text("Swipe back or tap ◀ at the top left to return to your app.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                LiveSessionPill()
                VStack(spacing: 14) {
                    if let progress = session.speechProgress {
                        SpeechModelProgress(fraction: progress)
                    }
                    if let problem = session.problem {
                        SessionProblem(message: problem, needsSettings: session.problemNeedsSettings)
                    }
                }
                .frame(maxWidth: 420)
            }
            Spacer()
            buttons
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topLeading) {
            if isListening { backHint }
        }
        .screenBackground()
    }

    // MARK: Pieces

    /// A small hint under the status bar, at the top left where iOS puts its own button back to the app.
    private var backHint: some View {
        Label("Back to your app", systemImage: "arrow.up.left")
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.leading, 20)
            .padding(.top, 8)
    }

    private var mark: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: phase == .idle)) { context in
            BubbleView(bars: BubbleMotion.bars(phase, level: Float(session.state.level),
                                               time: context.date.timeIntervalSinceReferenceDate))
        }
        .frame(width: 132, height: 115)
    }

    private var buttons: some View {
        VStack(spacing: 12) {
            if session.live {
                EndSessionButton {
                    Haptics.tap(enabled: store.settings.haptics)
                    session.endSession()
                }
            } else {
                Button {
                    Haptics.tap(enabled: store.settings.haptics)
                    Task { await session.startSession() }
                } label: {
                    PrimaryButtonLabel(title: "Try again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.glassProminent)
            }
            if dismissable {
                Button {
                    model.cover = nil
                } label: {
                    PrimaryButtonLabel(title: "Done")
                }
                .buttonStyle(.glass)
            }
        }
        .controlSize(.large)
        .frame(maxWidth: 420)
    }

    // MARK: State

    /// The session is on and the speech model is ready: the person can go back to the app they were typing in.
    private var isListening: Bool { session.live && session.speechProgress == nil }

    private var headline: LocalizedStringKey {
        if !session.live { return "Speak Away is not listening." }
        if session.speechProgress != nil { return "Getting the speech model ready. Stay here until it finishes." }
        return "Speak Away is listening"
    }

    private var phase: BubbleMotion.Phase {
        switch session.state {
        case .recording: return .listening
        case .transcribing: return .thinking
        default: return .idle
        }
    }
}
