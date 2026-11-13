import SwiftUI
import SpeakAwayCore

/// Tu voz: what Speak Away learns about how you talk and how you write. Three pages, the same ones the Mac has:
/// the dictionary, the voice shortcuts and the writing style.
struct VoiceView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var store: PhoneStore

    var body: some View {
        NavigationStack(path: $model.voicePath) {
            List {
                Text("Teach Speak Away your words, your phrases and the way you write.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 4, trailing: 4))
                Section {
                    entry(.dictionary, icon: "character.book.closed", title: "Dictionary",
                          detail: "Names, brands and words from your work", count: store.dictionary.entries.count)
                    entry(.snippets, icon: "text.badge.plus", title: "Voice shortcuts",
                          detail: "Say a short phrase, get a long text", count: store.snippets.items.count)
                    entry(.style, icon: "textformat", title: "Style",
                          detail: "How your text sounds in each kind of app", count: nil)
                }
            }
            .listStyle(.insetGrouped)
            .appList()
            .navigationTitle("Your voice")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: AppModel.VoiceRoute.self) { route in
                switch route {
                case .dictionary: DictionaryPage()
                case .snippets: SnippetsPage()
                case .style: StylePage()
                }
            }
        }
    }

    private func entry(_ route: AppModel.VoiceRoute, icon: String, title: LocalizedStringKey,
                       detail: LocalizedStringKey, count: Int?) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: 14) {
                IconTile(systemName: icon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(detail).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if let count {
                    Text(verbatim: "\(count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
        .cardRow()
    }
}

// MARK: Dictionary

private enum DictionaryTarget: Identifiable {
    case new
    case edit(DictionaryEntry)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let entry): return "edit-" + entry.word
        }
    }
}

/// Diccionario: names, brands and words from the person's work, with the ways they get misheard.
struct DictionaryPage: View {
    @EnvironmentObject private var store: PhoneStore
    @State private var target: DictionaryTarget?

    var body: some View {
        Group {
            if store.dictionary.entries.isEmpty {
                ScrollView {
                    VStack(spacing: 8) {
                        EmptyState(icon: "character.book.closed", title: "Your dictionary is empty",
                                   detail: "Add the name of your company, your clients or your jargon.")
                        Button { target = .new } label: {
                            PrimaryButtonLabel(title: "Add a word", systemImage: "plus")
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                        .padding(.horizontal, 56)
                    }
                }
            } else {
                List {
                    Text("Names, brands and words from your work. They are written the way you say, and what is often misheard gets fixed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 4, trailing: 4))
                    Section {
                        ForEach(store.dictionary.entries, id: \.word) { entry in
                            Button { target = .edit(entry) } label: { row(entry) }
                                .buttonStyle(.plain)
                                .cardRow()
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) { remove(entry) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .contextMenu {
                                    Button { target = .edit(entry) } label: { Label("Edit", systemImage: "pencil") }
                                    Button(role: .destructive) { remove(entry) } label: {
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
        .navigationTitle("Dictionary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { target = .new } label: { Label("Add a word", systemImage: "plus") }
            }
        }
        .sheet(item: $target) { target in
            DictionaryForm(target: target)
        }
        .screenBackground()
    }

    private func row(_ entry: DictionaryEntry) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.word).font(.headline)
            if !entry.replacing.isEmpty {
                Text("Instead of \(entry.replacing.joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func remove(_ entry: DictionaryEntry) {
        store.saveDictionary(store.dictionary.removing(word: entry.word))
    }
}

private struct DictionaryForm: View {
    let target: DictionaryTarget
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PhoneStore
    @State private var word: String
    @State private var heard: String

    init(target: DictionaryTarget) {
        self.target = target
        switch target {
        case .new:
            _word = State(initialValue: "")
            _heard = State(initialValue: "")
        case .edit(let entry):
            _word = State(initialValue: entry.word)
            _heard = State(initialValue: entry.replacing.joined(separator: ", "))
        }
    }

    private var cleanWord: String { word.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Word, for example “Speak Away”", text: $word)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("What it mishears, with commas (optional)", text: $heard)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("If your iPhone often writes the word wrong, list how it writes it. Speak Away fixes it every time.")
                }
            }
            .navigationTitle(isEditing ? "Edit word" : "New word")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(cleanWord.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var isEditing: Bool {
        if case .edit = target { return true }
        return false
    }

    private func save() {
        let replacing = heard.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let entry = DictionaryEntry(word: cleanWord, replacing: replacing)
        switch target {
        case .new: store.saveDictionary(store.dictionary.adding(entry))
        case .edit(let old): store.saveDictionary(store.dictionary.replacing(word: old.word, with: entry))
        }
        dismiss()
    }
}

// MARK: Voice shortcuts

private enum SnippetTarget: Identifiable {
    case new
    case edit(Snippet)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let snippet): return "edit-" + snippet.trigger
        }
    }
}

/// Atajos de voz: a short phrase that writes a long text.
struct SnippetsPage: View {
    @EnvironmentObject private var store: PhoneStore
    @State private var target: SnippetTarget?

    var body: some View {
        Group {
            if store.snippets.items.isEmpty {
                ScrollView {
                    VStack(spacing: 8) {
                        EmptyState(icon: "text.badge.plus", title: "No shortcuts yet",
                                   detail: "Your first shortcut saves you from typing the same thing every day.")
                        Button { target = .new } label: {
                            PrimaryButtonLabel(title: "Add a shortcut", systemImage: "plus")
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                        .padding(.horizontal, 56)
                    }
                }
            } else {
                List {
                    Text("Say a short phrase and a long text is written: your calendar link, your address, an answer you repeat.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 4, trailing: 4))
                    Section {
                        ForEach(store.snippets.items, id: \.trigger) { snippet in
                            Button { target = .edit(snippet) } label: { row(snippet) }
                                .buttonStyle(.plain)
                                .cardRow()
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) { remove(snippet) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .contextMenu {
                                    Button { target = .edit(snippet) } label: { Label("Edit", systemImage: "pencil") }
                                    Button(role: .destructive) { remove(snippet) } label: {
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
        .navigationTitle("Voice shortcuts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { target = .new } label: { Label("Add a shortcut", systemImage: "plus") }
            }
        }
        .sheet(item: $target) { target in
            SnippetForm(target: target)
        }
        .screenBackground()
    }

    private func row(_ snippet: Snippet) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: quoted(snippet.trigger)).font(.headline)
            Text(snippet.expansion)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// The phrase between the quotes of the interface language: «así» in Spanish, “like this” in English.
    private func quoted(_ phrase: String) -> String {
        UILanguage.isSpanish ? "«\(phrase)»" : "“\(phrase)”"
    }

    private func remove(_ snippet: Snippet) {
        store.saveSnippets(store.snippets.removing(trigger: snippet.trigger))
    }
}

private struct SnippetForm: View {
    let target: SnippetTarget
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PhoneStore
    @State private var trigger: String
    @State private var expansion: String

    init(target: SnippetTarget) {
        self.target = target
        switch target {
        case .new:
            _trigger = State(initialValue: "")
            _expansion = State(initialValue: "")
        case .edit(let snippet):
            _trigger = State(initialValue: snippet.trigger)
            _expansion = State(initialValue: snippet.expansion)
        }
    }

    private var cleanTrigger: String { trigger.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var cleanExpansion: String { expansion.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section("When I say…") {
                    TextField("for example “my calendar link”", text: $trigger)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("Write this") {
                    TextEditor(text: $expansion)
                        .frame(minHeight: 140)
                }
            }
            .navigationTitle(isEditing ? "Edit shortcut" : "New shortcut")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(cleanTrigger.isEmpty || cleanExpansion.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var isEditing: Bool {
        if case .edit = target { return true }
        return false
    }

    private func save() {
        let snippet = Snippet(trigger: cleanTrigger, expansion: cleanExpansion)
        switch target {
        case .new: store.saveSnippets(store.snippets.adding(snippet))
        case .edit(let old): store.saveSnippets(store.snippets.replacing(trigger: old.trigger, with: snippet))
        }
        dismiss()
    }
}

// MARK: Style

/// Estilo: how the text reads in each kind of field. The text you say is the same; how it is written changes.
struct StylePage: View {
    @EnvironmentObject private var store: PhoneStore

    private struct Kind: Identifiable {
        let category: AppCategory
        let title: LocalizedStringKey
        let apps: LocalizedStringKey
        let icon: String

        var id: AppCategory { category }
    }

    private let kinds: [Kind] = [
        Kind(category: .messages, title: "Messages", apps: "WhatsApp, iMessage, Telegram, Slack", icon: "message"),
        Kind(category: .email, title: "Email", apps: "Mail, Gmail, Outlook, Spark", icon: "envelope"),
        Kind(category: .work, title: "Work", apps: "Notes, Notion, Word, Pages, Teams", icon: "doc.text"),
        Kind(category: .other, title: "Other", apps: "Browser and other apps", icon: "square.grid.2x2"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("How your text sounds in each kind of app. What you say is the same; how it is written changes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
                ForEach(kinds) { kind in
                    Card {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 12) {
                                IconTile(systemName: kind.icon)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(kind.title).font(.headline)
                                    Text(kind.apps).font(.footnote).foregroundStyle(.secondary)
                                }
                            }
                            Picker(kind.title, selection: style(for: kind.category)) {
                                ForEach(WritingStyle.allCases, id: \.self) { style in
                                    Text(StyleText.title(style)).tag(style)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }
                Text("For now the keyboard uses Email in email fields and Messages everywhere else.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("Style")
        .navigationBarTitleDisplayMode(.inline)
        .screenBackground()
    }

    private func style(for category: AppCategory) -> Binding<WritingStyle> {
        Binding(get: { store.styles.style(for: category) },
                set: { store.setStyle($0, for: category) })
    }
}
