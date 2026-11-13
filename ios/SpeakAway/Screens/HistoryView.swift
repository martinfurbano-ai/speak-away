import SwiftUI
import UIKit
import SpeakAwayCore

/// Historial: everything dictated, a day at a time, newest first. Tap a row to copy it, swipe to delete it.
struct HistoryView: View {
    @EnvironmentObject private var store: PhoneStore
    @State private var query = ""
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("History")
                .navigationBarTitleDisplayMode(.large)
                .searchable(text: $query, prompt: "Search what you dictated")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { optionsMenu }
                }
                .toast($toast)
                .screenBackground()
        }
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        let items = History.search(store.history, query)
        if items.isEmpty {
            ScrollView { emptyState }
                .refreshable { store.reload() }
        } else {
            List {
                Text("What you dictated, kept only on your iPhone.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 4, trailing: 4))
                ForEach(HistoryGrouping.byDay(items)) { group in
                    Section {
                        ForEach(group.items) { item in
                            row(item)
                        }
                    } header: {
                        dayTitle(group.label)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .appList()
            .refreshable { store.reload() }
        }
    }

    private func row(_ item: HistoryItem) -> some View {
        Button {
            copy(item)
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(item.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cardRow()
        .accessibilityHint("Copies the text")
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                store.deleteHistory(item.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button { copy(item) } label: { Label("Copy", systemImage: "doc.on.doc") }
            Button(role: .destructive) { store.deleteHistory(item.id) } label: { Label("Delete", systemImage: "trash") }
        }
    }

    @ViewBuilder private func dayTitle(_ label: HistoryDayLabel) -> some View {
        switch label {
        case .today: Text("Today")
        case .yesterday: Text("Yesterday")
        case .date(let date): Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
        }
    }

    private var optionsMenu: some View {
        Menu {
            Toggle(isOn: Binding(get: { store.settings.historyEnabled },
                                 set: { value in store.updateSettings { $0.historyEnabled = value } })) {
                Label("Save history", systemImage: "clock.arrow.circlepath")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("History options")
    }

    // MARK: Empty

    @ViewBuilder private var emptyState: some View {
        if !query.isEmpty {
            EmptyState(icon: "magnifyingglass", title: "Nothing matches", detail: "Try another word.")
        } else if !store.settings.historyEnabled {
            VStack(spacing: 8) {
                EmptyState(icon: "clock.badge.xmark", title: "History is off",
                           detail: "Speak Away is not keeping what you dictate. Turn it on to see it here.")
                Button("Turn on history") {
                    store.updateSettings { $0.historyEnabled = true }
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            }
        } else {
            EmptyState(icon: "clock", title: "Nothing dictated yet",
                       detail: "Tap the mic on the Speak Away keyboard and what you say shows up here.")
        }
    }

    // MARK: Actions

    private func copy(_ item: HistoryItem) {
        UIPasteboard.general.string = item.text
        Haptics.success(enabled: store.settings.haptics)
        toast = String(localized: "Copied")
    }
}
