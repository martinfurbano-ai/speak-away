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
                    if session.live && session.speechProgress == nil {
                        Text("You can use the keyboard in any app now. The session keeps the microphone ready.")
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
        .screenBackground()
    }

    // MARK: Pieces

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
                Button {
                    Haptics.tap(enabled: store.settings.haptics)
                    session.endSession()
                } label: {
                    PrimaryButtonLabel(title: "End session", systemImage: "stop.fill")
                }
                .buttonStyle(.glassProminent)
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

    private var headline: LocalizedStringKey {
        if !session.live { return "Speak Away is not listening." }
        if session.speechProgress != nil { return "Getting the speech model ready. Stay here until it finishes." }
        return "Speak Away is listening. Swipe back to keep typing."
    }

    private var phase: BubbleMotion.Phase {
        switch session.state {
        case .recording: return .listening
        case .transcribing: return .thinking
        default: return .idle
        }
    }
}
