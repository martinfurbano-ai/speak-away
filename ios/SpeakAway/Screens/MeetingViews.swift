import SwiftUI
import UIKit
import SpeakAwayCore
import SpeakAwayBrain

// MARK: List

/// Reuniones: the saved meeting notes, newest first.
struct MeetingsList: View {
    @EnvironmentObject private var store: PhoneStore
    /// Starts a recording. The recorder arrives in a later step, so nothing is wired to this yet.
    var recordMeeting: () -> Void = {}

    private var meetings: [Meeting] {
        store.meetings.sorted { $0.startedAt > $1.startedAt }
    }

    var body: some View {
        if meetings.isEmpty {
            ScrollView {
                VStack(spacing: 8) {
                    EmptyState(icon: "person.2.wave.2", title: "No meeting notes yet",
                               detail: "Notes from your meetings will show up here, with the transcript and a summary.")
                    recordButton
                }
            }
        } else {
            List {
                if Features.meetingRecorder {
                    Section { recordButton.listRowBackground(Color.clear) }
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

    /// Only while the recorder is on: the flag stays off until the recorder exists.
    @ViewBuilder private var recordButton: some View {
        if Features.meetingRecorder {
            Button(action: recordMeeting) {
                PrimaryButtonLabel(title: "Record meeting", systemImage: "record.circle")
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .padding(.horizontal, 56)
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
                    ForEach(Meeting.turns(meeting.lines)) { TranscriptBubble(line: $0) }
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
        } else {
            Card {
                VStack(alignment: .leading, spacing: 6) {
                    Label("No summary yet", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(Theme.accent)
                    Text("Copy the meeting and paste it into ChatGPT or Claude to get one.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
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

/// One turn of the transcript as a chat bubble: yours on the right in red, theirs on the left.
struct TranscriptBubble: View {
    let line: TranscriptLine

    var body: some View {
        let mine = line.speaker == .me
        let who = mine ? String(localized: "Me") : String(localized: "Them")
        HStack(alignment: .bottom) {
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
}
