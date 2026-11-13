import SwiftUI
import SpeakAwayCore

extension AppModel {
    /// An empty note, opened for writing.
    func startNewNote() {
        let note = store.newNote()
        notesSegment = .pad
        notesPath.append(.note(note.id))
    }
}

/// Notas: the notepad (loose ideas, dictated or typed) and the meetings, in one tab with a segmented control.
struct NotesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack(path: $model.notesPath) {
            VStack(spacing: 0) {
                Picker("Notes", selection: $model.notesSegment) {
                    Text("Notepad").tag(AppModel.NotesSegment.pad)
                    Text("Meetings").tag(AppModel.NotesSegment.meetings)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                switch model.notesSegment {
                case .pad: NotepadList()
                case .meetings: MeetingsList()
                }
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if model.notesSegment == .pad {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { model.startNewNote() } label: { Label("New note", systemImage: "square.and.pencil") }
                    }
                }
            }
            .navigationDestination(for: AppModel.NotesRoute.self) { route in
                switch route {
                case .note(let id): NoteEditorView(noteID: id)
                case .meeting(let id): MeetingDetailView(meetingID: id)
                }
            }
            .screenBackground()
        }
    }
}

// MARK: Notepad

private struct NotepadList: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var store: PhoneStore

    var body: some View {
        if store.notes.isEmpty {
            ScrollView {
                VStack(spacing: 8) {
                    EmptyState(icon: "note.text", title: "Your notepad is empty",
                               detail: "Create a note and dictate what is on your mind.")
                    Button { model.startNewNote() } label: {
                        PrimaryButtonLabel(title: "New note", systemImage: "square.and.pencil")
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .padding(.horizontal, 56)
                }
            }
        } else {
            List {
                ForEach(store.notes) { note in
                    NavigationLink(value: AppModel.NotesRoute.note(note.id)) {
                        NoteRow(note: note)
                    }
                    .cardRow()
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            store.deleteNote(note.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .appList()
        }
    }
}

private struct NoteRow: View {
    let note: ScratchNote

    var body: some View {
        let outline = NoteOutline(text: note.text)
        VStack(alignment: .leading, spacing: 3) {
            Text(outline.title ?? String(localized: "New note"))
                .font(.headline)
                .lineLimit(1)
            if let preview = outline.preview {
                Text(preview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Text(note.updated.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: Editor

/// One note: the text, a dictate button that listens with the app's own session, and delete.
struct NoteEditorView: View {
    let noteID: UUID
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PhoneStore
    @EnvironmentObject private var dictation: NoteDictation
    @FocusState private var focused: Bool
    @State private var confirmDelete = false

    var body: some View {
        let text = store.note(noteID)?.text ?? ""
        TextEditor(text: Binding(get: { store.note(noteID)?.text ?? "" },
                                 set: { store.updateNote(noteID, text: $0) }))
            .font(.body)
            .scrollContentBackground(.hidden)
            .focused($focused)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 72)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) { dictateBar }
            .screenBackground()
            .navigationTitle(NoteOutline(text: text).title ?? String(localized: "New note"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete note", systemImage: "trash") }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focused = false }
                }
            }
            .confirmationDialog("Delete this note?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete note", role: .destructive) {
                    dictation.cancelIfListening()
                    store.deleteNote(noteID)
                    dismiss()
                }
            }
            .task {
                guard text.isEmpty else { return }
                try? await Task.sleep(for: .milliseconds(350))
                focused = true
            }
            .onAppear { dictation.clearMessage() }
            .onDisappear {
                dictation.cancelIfListening()
                if !dictation.isBusy { store.discardNoteIfEmpty(noteID) }
            }
    }

    // MARK: Dictate

    private var dictateBar: some View {
        VStack(spacing: 10) {
            if let message = dictation.message {
                VStack(spacing: 8) {
                    Text(message)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    if dictation.messageNeedsSettings {
                        Button("Open Settings") { SettingsLink.open() }
                            .buttonStyle(.glass)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 24)
            }
            Button {
                focused = false
                Haptics.tap(enabled: store.settings.haptics)
                dictation.toggle(note: noteID)
            } label: {
                dictateLabel
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(dictation.phase == .starting || dictation.phase == .writing)
        }
        .padding(.bottom, 20)
    }

    @ViewBuilder private var dictateLabel: some View {
        switch dictation.phase {
        case .idle:
            Label("Dictate", systemImage: "mic.fill")
        case .starting:
            Label("Getting ready", systemImage: "hourglass")
        case .listening:
            Label("Stop", systemImage: "stop.fill")
        case .writing:
            Label("Writing it down", systemImage: "ellipsis")
        }
    }
}
