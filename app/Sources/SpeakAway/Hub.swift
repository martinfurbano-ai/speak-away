import AppKit
import ServiceManagement
import SpeakAwayCore
import SwiftUI

/// The main window: a Liquid Glass sidebar (macOS 26) and pure white or pure black pages.
enum HubSection: String, CaseIterable, Identifiable {
    case inicio, historial, bloc, reuniones, diccionario, atajos, estilo, ajustes
    var id: String { rawValue }

    var title: String {
        switch self {
        case .inicio: return "Inicio"
        case .historial: return "Historial"
        case .bloc: return "Bloc de notas"
        case .reuniones: return "Reuniones"
        case .diccionario: return "Diccionario"
        case .atajos: return "Atajos de voz"
        case .estilo: return "Estilo"
        case .ajustes: return "Ajustes"
        }
    }

    var icon: String {
        switch self {
        case .inicio: return "house"
        case .historial: return "clock"
        case .bloc: return "note.text"
        case .reuniones: return "person.2.wave.2"
        case .diccionario: return "character.book.closed"
        case .atajos: return "text.badge.plus"
        case .estilo: return "textformat"
        case .ajustes: return "gearshape"
        }
    }
}

@MainActor
final class HubModel: ObservableObject {
    @Published var section: HubSection = .inicio
}

struct HubView: View {
    @ObservedObject var model: HubModel
    let stores: HubStores
    @ObservedObject var engine: Engine
    var previewReady = false
    var openPermissions: () -> Void = {}
    var pages: [HubSection: AnyView] = [:]

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(get: { model.section }, set: { if let s = $0 { model.section = s } })) {
                Section {
                    ForEach([HubSection.inicio, .historial, .bloc, .reuniones]) { row($0) }
                }
                Section("Tu voz") {
                    ForEach([HubSection.diccionario, .atajos, .estilo]) { row($0) }
                }
                Section {
                    row(.ajustes)
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 200, max: 240)
            .safeAreaInset(edge: .bottom) { credit }
        } detail: {
            ScrollView {
                page(model.section)
                    .frame(maxWidth: 760, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(Theme.background)
            .scrollContentBackground(.hidden)
        }
        .modifier(NoWindowTitle())
        .tint(Theme.accent)
        .frame(minWidth: 900, minHeight: 640)
    }

    private func row(_ s: HubSection) -> some View {
        Label(s.title, systemImage: s.icon).tag(s)
    }

    private var credit: some View {
        Link(destination: Settings.instagram) {
            HStack(spacing: 8) {
                BubbleView(bars: BubbleMotion.bars(.idle, level: 0, time: 0)).frame(width: 20, height: 18)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Open Source Everything").font(.system(size: 11, weight: .semibold))
                    Text("por Martín Urbano").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    @ViewBuilder private func page(_ s: HubSection) -> some View {
        if s == .inicio {
            HomeView(store: stores.stats, engine: engine, previewReady: previewReady)
        } else if s == .historial {
            HistoryPage(history: stores.history)
        } else if s == .bloc {
            ScratchpadPage(store: stores.scratchpad)
        } else if s == .reuniones {
            MeetingsPage(model: stores.meetings, recorder: stores.meetings.recorder)
        } else if s == .diccionario {
            DictionaryPage(store: stores.dictionary)
        } else if s == .atajos {
            SnippetsPage(store: stores.snippets)
        } else if s == .estilo {
            StylePage(store: stores.styles)
        } else if s == .ajustes {
            SettingsPage(engine: engine, openPermissions: openPermissions)
        } else if let custom = pages[s] {
            custom
        } else {
            PagePlaceholder(section: s)
        }
    }
}

/// Shared page chrome: big title, one line of help, then the content.
struct PageHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 28, weight: .bold)).kerning(-0.6)
            Text(subtitle).font(.system(size: 14)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A rounded card that stays solid for legibility; Liquid Glass is kept for things that float.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
    }
}

private struct PagePlaceholder: View {
    let section: HubSection
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeader(title: section.title, subtitle: "En camino.")
        }
        .padding(28)
    }
}

/// Settings: mic, language, model, sounds, open at login, shortcut and permissions.
struct SettingsPage: View {
    @ObservedObject var engine: Engine
    var openPermissions: () -> Void
    @State private var mic = Settings.microphone
    @State private var language = Settings.language
    @State private var modelID = Settings.model
    @State private var sounds = Settings.sounds
    @State private var atLogin = SMAppService.mainApp.status == .enabled
    @State private var devices = Microphones.all()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeader(title: "Ajustes", subtitle: "Todo corre en tu Mac. Nada de esto sale de tu computadora.")
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    row("Micrófono", "mic") {
                        Picker("", selection: $mic) {
                            Text("El del sistema").tag("")
                            ForEach(devices) { Text($0.name).tag($0.id) }
                        }
                        .labelsHidden().fixedSize()
                        .onChange(of: mic) { _, v in Settings.microphone = v }
                    }
                    Divider()
                    row("Idioma", "globe") {
                        Picker("", selection: $language) { ForEach(Settings.languages, id: \.id) { Text($0.label).tag($0.id) } }
                            .labelsHidden().fixedSize()
                            .onChange(of: language) { _, v in Settings.language = v }
                    }
                    Divider()
                    row("Modelo de voz", "waveform") {
                        Picker("", selection: $modelID) { ForEach(Settings.models, id: \.id) { Text($0.label).tag($0.id) } }
                            .labelsHidden().fixedSize()
                            .onChange(of: modelID) { _, v in Settings.model = v; engine.prepare() }
                    }
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    row("Sonidos al dictar", "speaker.wave.2") {
                        Toggle("", isOn: $sounds).labelsHidden().toggleStyle(.switch)
                            .onChange(of: sounds) { _, v in Settings.sounds = v }
                    }
                    Divider()
                    row("Abrir al iniciar sesión", "power") {
                        Toggle("", isOn: $atLogin).labelsHidden().toggleStyle(.switch)
                            .onChange(of: atLogin) { _, v in
                                do { v ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister() } catch { atLogin = !v }
                            }
                    }
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Atajo").font(.system(size: 15, weight: .semibold))
                    shortcut(["fn"], "Mantén para dictar y suelta para pegar")
                    shortcut(["fn", "fn"], "Dos toques para dictar sin manos; un toque para terminar")
                    HStack {
                        Text("Si Fn abre los emojis: Ajustes del Sistema › Teclado › «Pulsar la tecla 🌐 para» › No hacer nada.")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                        Spacer()
                        Button("Permisos…", action: openPermissions)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(28)
    }

    private func row<Trailing: View>(_ title: String, _ icon: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            Label(title, systemImage: icon).font(.system(size: 14))
            Spacer()
            trailing().frame(minWidth: 220, alignment: .trailing)
        }
    }

    private func shortcut(_ keys: [String], _ text: String) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, k in Keycap(k) }
            Text(text).font(.system(size: 13)).foregroundStyle(.secondary).padding(.leading, 4)
        }
    }
}

final class HubWindow: NSWindow {
    let model = HubModel()

    init(stores: HubStores, engine: Engine, previewReady: Bool = false, openPermissions: @escaping () -> Void = {}, pages: [HubSection: AnyView] = [:]) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 720),
                   styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        contentViewController = NSHostingController(rootView: HubView(model: model, stores: stores, engine: engine, previewReady: previewReady, openPermissions: openPermissions, pages: pages))
        title = "Speak Away"
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        backgroundColor = Theme.backgroundNS
        isReleasedWhenClosed = false
        setContentSize(NSSize(width: 1000, height: 720))
        center()
    }
}

/// Hides the "Speak Away" title in the toolbar on macOS 15 and newer; older macOS keeps it.
private struct NoWindowTitle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) { content.toolbar(removing: .title) } else { content }
    }
}
