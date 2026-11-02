import AppKit
import SpeakAwayCore
import SwiftUI

/// Everything the hub pages read, created once by the app (or with sample data by --preview-home).
@MainActor
struct HubStores {
    let stats: StatsStore
    let history: HistoryStore
    let scratchpad: ScratchpadStore
    let dictionary: ObservableJSONStore<PersonalDictionary>
    let snippets: ObservableJSONStore<Snippets>
    let styles: ObservableJSONStore<StyleSettings>
    let meetings: MeetingsModel
}

// MARK: Historial

struct HistoryPage: View {
    @ObservedObject var history: HistoryStore
    @State private var query = ""
    @State private var copied: UUID?

    var body: some View {
        let items = (query.isEmpty ? history.items : history.search(query)).sorted { $0.date > $1.date }
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                PageHeader(title: "Historial", subtitle: "Lo que dictaste, guardado solo en tu Mac.")
                Toggle("Guardar", isOn: $history.isEnabled).toggleStyle(.switch).font(.system(size: 13))
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Buscar en lo que dictaste", text: $query).textFieldStyle(.plain).font(.system(size: 14))
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Capsule().fill(Theme.card))

            if items.isEmpty {
                EmptyState(icon: history.isEnabled ? "clock" : "clock.badge.xmark",
                           title: query.isEmpty ? (history.isEnabled ? "Todavía no hay dictados" : "El historial está apagado") : "Nada coincide",
                           detail: query.isEmpty ? "Toca Fn dos veces en cualquier app y lo que digas aparece aquí." : "Prueba con otra palabra.")
            } else {
                ForEach(groups(items), id: \.0) { day, rows in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(day).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                        VStack(spacing: 0) {
                            ForEach(rows) { item in
                                row(item)
                                if item.id != rows.last?.id { Divider().padding(.leading, 16) }
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
                    }
                }
            }
        }
        .padding(28)
    }

    private func row(_ item: HistoryItem) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.date.formatted(date: .omitted, time: .shortened)).font(.system(size: 12, weight: .medium)).monospacedDigit()
                if let app = item.app { Text(app).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1) }
            }
            .frame(width: 84, alignment: .leading)
            Text(item.text).font(.system(size: 14)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 4) {
                Button { copy(item) } label: { Image(systemName: copied == item.id ? "checkmark" : "doc.on.doc") }
                    .help("Copiar")
                Button { history.delete(item.id) } label: { Image(systemName: "trash") }
                    .help("Borrar")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func copy(_ item: HistoryItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
        copied = item.id
    }

    private func groups(_ items: [HistoryItem]) -> [(String, [HistoryItem])] {
        let cal = Calendar.current
        var order: [String] = []
        var map: [String: [HistoryItem]] = [:]
        for item in items {
            let key = cal.isDateInToday(item.date) ? "Hoy" : cal.isDateInYesterday(item.date) ? "Ayer"
                : item.date.formatted(.dateTime.weekday(.wide).day().month(.wide))
            if map[key] == nil { order.append(key) }
            map[key, default: []].append(item)
        }
        return order.map { ($0, map[$0]!) }
    }
}

// MARK: Bloc de notas

struct ScratchpadPage: View {
    @ObservedObject var store: ScratchpadStore
    @State private var selected: UUID?
    @State private var draft = ""
    @FocusState private var editing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                PageHeader(title: "Bloc de notas", subtitle: "Ideas sueltas. Haz clic en la nota y dicta con Fn: se escribe aquí.")
                Button { newNote() } label: { Label("Nueva nota", systemImage: "square.and.pencil") }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            }
            if store.notes.isEmpty {
                EmptyState(icon: "note.text", title: "Tu bloc está vacío", detail: "Crea una nota y dicta lo que tengas en la cabeza.")
            } else {
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 6) {
                        ForEach(store.notes) { note in
                            Button { open(note) } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(note.title.isEmpty ? "Nota nueva" : note.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                                    Text(note.updated.formatted(.relative(presentation: .named))).font(.system(size: 11)).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12).padding(.vertical, 9)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(selected == note.id ? Theme.accent.opacity(0.12) : .clear))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(width: 200)
                    VStack(alignment: .trailing, spacing: 8) {
                        TextEditor(text: $draft)
                            .font(.system(size: 16))
                            .scrollContentBackground(.hidden)
                            .focused($editing)
                            .padding(14)
                            .frame(minHeight: 420)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
                            .onChange(of: draft) { _, text in if let id = selected { store.update(id, text: text) } }
                        if let id = selected {
                            Button(role: .destructive) { store.delete(id); selected = nil; draft = ""; if let first = store.notes.first { open(first) } } label: {
                                Label("Borrar nota", systemImage: "trash")
                            }
                            .buttonStyle(.borderless).foregroundStyle(.secondary).font(.system(size: 12))
                        }
                    }
                }
            }
        }
        .padding(28)
        .onAppear { if selected == nil, let first = store.notes.first { open(first) } }
    }

    private func open(_ note: ScratchNote) {
        selected = note.id
        draft = note.text
    }

    private func newNote() {
        let note = store.add("")
        open(note)
        editing = true
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let detail: String
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.1)).frame(width: 64, height: 64)
                Image(systemName: icon).font(.system(size: 26, weight: .medium)).foregroundStyle(Theme.accent)
            }
            Text(title).font(.system(size: 17, weight: .semibold))
            Text(detail).font(.system(size: 13)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
    }
}
