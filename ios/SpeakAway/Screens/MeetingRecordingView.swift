import SwiftUI
import SpeakAwayCore

/// The meeting being recorded: its name, how long it has run, how loud the room is, the words as they are heard,
/// and the two buttons that matter. The recording goes on when the screen is left or the phone is locked; the
/// Meetings list keeps a row that comes back here.
struct MeetingRecordingView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var recorder: MeetingRecorder
    @EnvironmentObject private var store: PhoneStore
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(spacing: 14) {
            switch recorder.stage {
            case .preparing: preparing
            case .recording, .paused, .finishing: live
            case .idle: idle
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
        .navigationTitle("Recording")
        .navigationBarTitleDisplayMode(.inline)
        .toast($recorder.notice)
        .onAppear(perform: leaveIfOver)
        .onChange(of: recorder.stage) { old, new in
            if new == .idle, old != .idle { leaveIfOver() }
        }
    }

    /// The meeting ended, whoever ended it (and even while another tab was open): its note opens, or the list comes
    /// back when nothing was kept. A start that failed stays here, so the reason can be read.
    private func leaveIfOver() {
        guard recorder.stage == .idle, recorder.problem == nil else { return }
        model.openSavedMeeting(recorder.lastSaved)
    }

    // MARK: Getting ready

    private var preparing: some View {
        VStack(spacing: 22) {
            Spacer()
            LevelBars(phase: .thinking, level: 0, color: Theme.accent, height: 44)
            Text(preparingHeadline)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let progress = recorder.speechProgress {
                SpeechModelProgress(fraction: progress).frame(maxWidth: 420)
            }
            Spacer()
            Button {
                Task { await recorder.stop() }
            } label: {
                PrimaryButtonLabel(title: "Cancel")
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            .frame(maxWidth: 420)
        }
    }

    private var preparingHeadline: LocalizedStringKey {
        recorder.speechProgress == nil ? "Getting ready" : "Getting the speech model ready. Stay here until it finishes."
    }

    // MARK: Recording

    @ViewBuilder private var live: some View {
        header
        LiveTranscriptCard(transcript: recorder.transcript)
        if let problem = recorder.problem {
            SessionProblem(message: problem, needsSettings: recorder.problemNeedsSettings)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
        }
        controls
        footnote
    }

    private var paused: Bool { recorder.stage == .paused }

    private var header: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                TextField(recorder.defaultTitle, text: $recorder.title)
                    .font(.title3.weight(.semibold))
                    .submitLabel(.done)
                    .focused($titleFocused)
                    .onSubmit { recorder.commitTitle() }
                    .onChange(of: titleFocused) { _, focused in
                        if !focused { recorder.commitTitle() }
                    }
                    .disabled(recorder.stage == .finishing)
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        ElapsedClock(meter: recorder.meter)
                            .font(.system(size: 46, weight: .semibold, design: .rounded))
                        SessionPill(badge: .meeting(paused: paused))
                    }
                    Spacer(minLength: 8)
                    MeterBars(meter: recorder.meter, listening: recorder.stage == .recording)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var controls: some View {
        if recorder.stage == .finishing {
            HStack(spacing: 10) {
                ProgressView()
                Text("Saving the notes").font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        } else {
            let pauseTitle: LocalizedStringKey = paused ? "Resume" : "Pause"
            HStack(spacing: 12) {
                Button {
                    Haptics.tap(enabled: store.settings.haptics)
                    recorder.togglePause()
                } label: {
                    PrimaryButtonLabel(title: pauseTitle, systemImage: paused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(.glass)
                Button {
                    Haptics.tap(enabled: store.settings.haptics)
                    Task { await recorder.stop() }
                } label: {
                    PrimaryButtonLabel(title: "Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.glassProminent)
            }
            .controlSize(.large)
        }
    }

    private var footnote: some View {
        Text("Only the words are kept, never the audio. Let people know you are recording.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
    }

    // MARK: Not recording

    /// The meeting did not start: why, and a way to try again. When nothing is wrong the screen is about to close.
    @ViewBuilder private var idle: some View {
        Spacer()
        if let problem = recorder.problem {
            VStack(spacing: 18) {
                SessionProblem(message: problem, needsSettings: recorder.problemNeedsSettings)
                Button {
                    model.startMeetingRecording()
                } label: {
                    PrimaryButtonLabel(title: "Try again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            }
            .frame(maxWidth: 420)
        }
        Spacer()
        footnote
    }
}

// MARK: Pieces

/// The counter: `0:07`, `12:34`, `1:02:03`. It watches the meter alone, so the words do not redraw with it.
struct ElapsedClock: View {
    @ObservedObject var meter: MeterModel

    var body: some View {
        Text(verbatim: ElapsedFormat.string(meter.elapsed))
            .monospacedDigit()
    }
}

/// The mark as three bars that follow the room's voice while recording and rest while paused.
private struct MeterBars: View {
    @ObservedObject var meter: MeterModel
    let listening: Bool

    var body: some View {
        LevelBars(phase: listening ? .listening : .idle, level: meter.level, color: Theme.accent, height: 40)
    }
}

/// The words so far, newest at the bottom. The engine's current guess follows them in a lighter color until it
/// settles. The card opens on the newest words and keeps its bottom edge as more arrive.
private struct LiveTranscriptCard: View {
    let transcript: LiveTranscript

    var body: some View {
        Card(padding: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if transcript.lines.isEmpty && transcript.volatile.isEmpty {
                        Text("Say something and the words show up here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    // Two markers can share a time (a pause and its resume), so the position is the identity.
                    ForEach(Array(transcript.lines.enumerated()), id: \.offset) { _, line in
                        TranscriptBubble(line: line)
                    }
                    if !transcript.volatile.isEmpty {
                        Text(transcript.volatile)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .defaultScrollAnchor(.bottom, for: .initialOffset)
            .defaultScrollAnchor(.bottom, for: .sizeChanges)
            .scrollDismissesKeyboard(.interactively)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}
