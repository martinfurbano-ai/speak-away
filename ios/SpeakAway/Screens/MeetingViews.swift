import SwiftUI
import UIKit
import SpeakAwayCore
import SpeakAwayBrain

// MARK: List

/// Reuniones: the meeting being recorded on top, then the saved meeting notes, newest first.
struct MeetingsList: View {
    @EnvironmentObject private var store: PhoneStore
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var recorder: MeetingRecorder

    private var meetings: [Meeting] {
        store.meetings.sorted { $0.startedAt > $1.startedAt }
    }

    var body: some View {
        Group {
            if meetings.isEmpty && !recorder.isActive {
                ScrollView {
                    VStack(spacing: 8) {
                        EmptyState(icon: "person.2.wave.2", title: "No meeting notes yet",
                                   detail: "Notes from your meetings will show up here, with the transcript and a summary.")
                        recordButton
                    }
                }
            } else {
                List {
                    if Features.meetingRecorder || recorder.isActive {
                        Section {
                            if recorder.isActive {
                                NavigationLink(value: AppModel.NotesRoute.recording) {
                                    RecordingRow(title: recorder.shownTitle, stage: recorder.stage, meter: recorder.meter)
                                }
                                .cardRow()
                            } else {
                                recordButton.listRowBackground(Color.clear)
                            }
                        }
                    }
                    Section {
                        ForEach(meetings) { meeting in
                            NavigationLink(value: AppModel.NotesRoute.meeting(meeting.id)) {
                                MeetingRow(meeting: meeting)
                            }
                            .cardRow()
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    store.deleteMeeting(meeting.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .appList()
            }
        }
        .toast($recorder.notice)
    }

    @ViewBuilder private var recordButton: some View {
        if Features.meetingRecorder {
            Button { model.startMeetingRecording() } label: {
                // Not a `Label`: in a list row a label draws its icon in the accent color, which is the color of this
                // button, so the icon vanished. Drawn by hand, in white like the title.
                HStack(spacing: 8) {
                    Image(systemName: "record.circle").foregroundStyle(.white)
                    Text("Record meeting")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .padding(.horizontal, 56)
        }
    }
}

/// The meeting being recorded, as a row: the way back to its screen.
private struct RecordingRow: View {
    let title: String
    let stage: MeetingRecorder.Stage
    let meter: MeterModel

    var body: some View {
        HStack(spacing: 14) {
            IconTile(systemName: "record.circle")
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title).font(.headline).lineLimit(1)
                HStack(spacing: 6) {
                    status
                    if stage == .recording || stage == .paused {
                        Text(verbatim: "·")
                        ElapsedClock(meter: meter)
                    }
                }
                .font(.footnote)
                .foregroundStyle(stage == .recording ? Theme.accent : Color.secondary)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private var status: some View {
        switch stage {
        case .idle, .preparing: Text("Getting ready")
        case .recording: Text("Recording")
        case .paused: Text("Paused")
        case .finishing: Text("Saving the notes")
        }
    }
}

private struct MeetingRow: View {
    let meeting: Meeting

    var body: some View {
        HStack(spacing: 14) {
            IconTile(systemName: meeting.summary == nil ? "waveform" : "sparkles")
            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.title).font(.headline).lineLimit(1)
                Text(verbatim: MeetingFormat.details(meeting, dateStyle: .abbreviated))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

/// How a meeting is described in one line: where it was, when, and for how long.
enum MeetingFormat {
    static func details(_ meeting: Meeting, dateStyle: Date.FormatStyle.DateStyle) -> String {
        let when = meeting.startedAt.formatted(date: dateStyle, time: .shortened)
        let minutes = max(1, Int((meeting.duration / 60).rounded()))
        return "\(meeting.app) · \(when) · \(minutes) min"
    }
}

// MARK: Detail

/// One meeting: the summary in its sections, the transcript as a conversation, and the button that copies it all
/// for a chat assistant.
struct MeetingDetailView: View {
    let meetingID: UUID
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PhoneStore
    @EnvironmentObject private var recorder: MeetingRecorder
    @State private var toast: String?
    @State private var confirmDelete = false

    var body: some View {
        Group {
            if let meeting = store.meeting(meetingID) {
                content(meeting)
            } else {
                EmptyState(icon: "person.2.wave.2", title: "This meeting is gone", detail: "It was deleted.")
            }
        }
        .toast($toast)
        .toast($recorder.notice)
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(_ meeting: Meeting) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(meeting.title).font(.title.weight(.bold))
                    Text(verbatim: MeetingFormat.details(meeting, dateStyle: .long))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 6)

                Button { copyForChat(meeting) } label: {
                    PrimaryButtonLabel(title: "Copy for ChatGPT", systemImage: "doc.on.doc")
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)

                summary(meeting)

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Transcript")
                    // Two markers can share a time (a pause and its resume), so the position is the identity.
                    ForEach(Array(Meeting.turns(meeting.lines).enumerated()), id: \.offset) { _, line in
                        TranscriptBubble(line: line)
                    }
                }

                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("Delete meeting", systemImage: "trash").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .confirmationDialog("Delete this meeting?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete meeting", role: .destructive) {
                store.deleteMeeting(meeting.id)
                dismiss()
            }
        }
    }

    // MARK: Summary

    @ViewBuilder private func summary(_ meeting: Meeting) -> some View {
        if let text = meeting.summary, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let parts = MeetingSummary(markdown: text) {
                if !parts.summary.isEmpty {
                    SummaryCard(title: "Summary", icon: "sparkles", paragraph: parts.summary)
                }
                if !parts.decisions.isEmpty {
                    SummaryCard(title: "Decisions", icon: "checkmark.seal", items: parts.decisions, marker: "circle.fill")
                }
                if !parts.actionItems.isEmpty {
                    SummaryCard(title: "Action items", icon: "list.bullet.clipboard", items: parts.actionItems, marker: "circle")
                }
                if !parts.questions.isEmpty {
                    SummaryCard(title: "Open questions", icon: "questionmark.bubble", items: parts.questions, marker: "circle.fill")
                }
            } else {
                SummaryCard(title: "Summary", icon: "sparkles", paragraph: text)
            }
        } else if recorder.summarizing == meeting.id {
            Card {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Summarizing on your iPhone").font(.headline)
                }
            }
        } else {
            noSummary(meeting)
        }
    }

    /// No notes yet: why, and the way to get them when this iPhone can write them.
    private func noSummary(_ meeting: Meeting) -> some View {
        let plan = recorder.summaryPlan(for: meeting)
        let title: LocalizedStringKey = plan == .needsAppleIntelligence ? "The summary needs Apple Intelligence" : "No summary yet"
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
                Text(verbatim: noSummaryDetail(plan))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if plan == .summarizeNow || plan == .leaveForLater {
                    Button {
                        Task { await recorder.summarize(meeting.id) }
                    } label: {
                        PrimaryButtonLabel(title: "Summarize", systemImage: "sparkles")
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }

    private func noSummaryDetail(_ plan: SummaryPlan) -> String {
        switch plan {
        case .nothingToSummarize:
            return String(localized: "Too little was said to make a summary.")
        case .brainOff:
            return String(localized: "Turn on Brain in Settings to get a summary on your iPhone.")
        case .needsAppleIntelligence:
            return PhoneText.brainSettingsDetail(recorder.brainStatus())
        case .leaveForLater:
            return PhoneText.brainSettingsDetail(.modelNotReady)
        case .summarizeNow:
            return String(localized: "Write the summary, decisions and tasks on your iPhone. Nothing leaves your phone.")
        }
    }

    private func copyForChat(_ meeting: Meeting) {
        UIPasteboard.general.string = meeting.chatPrompt(english: !UILanguage.isSpanish)
        Haptics.success(enabled: store.settings.haptics)
        toast = String(localized: "Copied. Paste it into ChatGPT or Claude.")
    }
}

// MARK: Pieces

/// One section of the notes: a title with its icon, then a paragraph or a list.
private struct SummaryCard: View {
    let title: LocalizedStringKey
    let icon: String
    var paragraph: String?
    var items: [String] = []
    var marker = "circle.fill"

    init(title: LocalizedStringKey, icon: String, paragraph: String) {
        self.title = title
        self.icon = icon
        self.paragraph = paragraph
    }

    init(title: LocalizedStringKey, icon: String, items: [String], marker: String) {
        self.title = title
        self.icon = icon
        self.items = items
        self.marker = marker
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
                if let paragraph {
                    Text(paragraph).font(.body).fixedSize(horizontal: false, vertical: true)
                }
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: marker)
                            .font(.system(size: marker == "circle" ? 11 : 6, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 12)
                        Text(item).font(.body).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

/// One turn of the transcript. On a call it is a chat bubble, yours on the right in red and theirs on the left.
/// In a room (one microphone, nobody told apart) it is the time and the paragraph. A marker (a pause, a call that
/// cut in) is a small note in the middle.
struct TranscriptBubble: View {
    let line: TranscriptLine

    var body: some View {
        switch line.speaker {
        case .me, .them: bubble
        case .room: paragraph
        case .marker: marker
        }
    }

    private var bubble: some View {
        let mine = line.speaker == .me
        let who = mine ? String(localized: "Me") : String(localized: "Them")
        return HStack(alignment: .bottom) {
            if mine { Spacer(minLength: 48) }
            VStack(alignment: mine ? .trailing : .leading, spacing: 3) {
                Text(verbatim: "\(who) · \(Meeting.clock(line.start))")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(line.text)
                    .font(.body)
                    .foregroundStyle(mine ? Color.white : Color.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(mine ? Theme.accent : Theme.card,
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            if !mine { Spacer(minLength: 48) }
        }
    }

    private var paragraph: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: Meeting.clock(line.start))
                .font(.caption2.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
            Text(line.text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var marker: some View {
        Text(verbatim: "\(Meeting.clock(line.start)) · \(line.text)")
            .font(.caption.italic())
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
    }
}
