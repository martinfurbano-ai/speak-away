import AppKit
import Combine
import SpeakAwayCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum Mode { case idle, recording, transcribing }

    private let engine = Engine()
    private let recorder = Recorder()
    private let fn = FnListener()
    private let hudModel = HUDModel()
    private lazy var hud = HUDPanel(model: hudModel)

    private var statusItem: NSStatusItem!
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var welcome: WelcomeWindow?
    private let stats = StatsStore()
    private let history = HistoryStore()
    private let scratchpad = ScratchpadStore()
    private var home: HubWindow?
    private let sounds = Sounds()
    private var mode = Mode.idle { didSet { animateGlyph() } }
    private var tap = FnTap()
    private var hideWork: DispatchWorkItem?
    private var bag = Set<AnyCancellable>()
    private var permissionTimer: Timer?
    private var glyphTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        engine.$state.receive(on: RunLoop.main).sink { [weak self] _ in self?.refreshStatus() }.store(in: &bag)
        engine.prepare()

        recorder.onLevel = { [weak self] level in
            DispatchQueue.main.async { self?.hudModel.level = level }
        }
        fn.onFnDown = { [weak self] in
            DispatchQueue.main.async { self?.fnPressed() }
        }
        fn.onOtherKey = { [weak self] in
            DispatchQueue.main.async { self?.tap = self?.tap.otherKey() ?? FnTap() }
        }
        fn.start()
        // Input Monitoring can be granted while the app runs: keep trying until the Fn listener is on.
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if !self.fn.isRunning { self.fn.start() }
                self.refreshStatus()
            }
        }

        if !Settings.welcomed || !Permission.allGranted { showWelcome() } else { showHome() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showHome()
        return true
    }

    // MARK: Dictation

    private func fnPressed() {
        let (next, action) = tap.press(at: ProcessInfo.processInfo.systemUptime, recording: mode == .recording)
        tap = next
        switch action {
        case .start: startRecording()
        case .stop: stopRecording()
        case nil: break
        }
    }

    private func startRecording() {
        guard mode == .idle else { return }
        guard engine.isReady else { return flash(waitingLabel) }
        guard Permission.microphone.granted else {
            Permission.microphone.request()
            return flash("FALTA EL MICRÓFONO")
        }
        do {
            try recorder.start()
        } catch {
            return flash("SIN MICRÓFONO")
        }
        mode = .recording
        hideWork?.cancel()
        hudModel.level = 0
        hudModel.phase = .listening
        hud.showOnActiveScreen()
        sounds.play(.start)
    }

    private func stopRecording() {
        guard mode == .recording else { return }
        let audio = recorder.stop()
        sounds.play(.stop)
        hudModel.level = 0
        guard SpeechGate.check(audio, sampleRate: Recorder.sampleRate) == .speech else {
            mode = .idle
            return hideHUD(after: 0)
        }
        mode = .transcribing
        hudModel.phase = .transcribing
        Task {
            defer { mode = .idle }
            do {
                let text = SpeechGate.clean(try await engine.transcribe(audio))
                guard !text.isEmpty else { return hideHUD(after: 0) }
                Paster.paste(text)
                sounds.play(.paste)
                stats.record(text: text, seconds: Double(audio.count) / Double(Recorder.sampleRate))
                history.add(text: text, raw: text, app: NSWorkspace.shared.frontmostApplication?.localizedName)
                hudModel.phase = Permission.paste.granted ? .pasted : .note("COPIADO, USA ⌘V")
                hideHUD(after: 1.1)
            } catch {
                flash("NO SE PUDO TRANSCRIBIR")
            }
        }
    }

    private var waitingLabel: String {
        if case .downloading(let p) = engine.state { return "DESCARGANDO \(Int(p * 100)) %" }
        return "PREPARANDO EL MODELO"
    }

    private func flash(_ text: String) {
        hudModel.phase = .note(text)
        hud.showOnActiveScreen()
        hideHUD(after: 1.8)
    }

    private func hideHUD(after seconds: Double) {
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.mode != .recording else { return }
            self.hud.orderOut(nil)
            self.hudModel.phase = .hidden
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    // MARK: Menu bar glyph

    /// The bubble in the menu bar moves like the HUD: voice bars while recording, typing dots while transcribing.
    private func animateGlyph() {
        glyphTimer?.invalidate()
        glyphTimer = nil
        guard mode != .idle else {
            statusItem?.button?.image = BubbleMark.menuBarImage(BubbleMotion.bars(.idle, level: 0, time: 0))
            return
        }
        glyphTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let phase: BubbleMotion.Phase = self.mode == .recording ? .listening : .thinking
                let bars = BubbleMotion.bars(phase, level: self.hudModel.level, time: ProcessInfo.processInfo.systemUptime)
                self.statusItem.button?.image = BubbleMark.menuBarImage(bars)
            }
        }
    }

    // MARK: Menu

    private func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = BubbleMark.menuBarImage(BubbleMotion.bars(.idle, level: 0, time: 0))

        let menu = NSMenu()
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())
        menu.addItem(item("Abrir Speak Away", #selector(openHome)))
        menu.addItem(submenu("Idioma", options: Settings.languages, current: { Settings.language }) { Settings.language = $0 })
        menu.addItem(submenu("Modelo", options: Settings.models, current: { Settings.model }) { [weak self] id in
            Settings.model = id
            self?.engine.prepare()
        })
        menu.addItem(item("Permisos…", #selector(openWelcome)))
        menu.addItem(.separator())
        menu.addItem(item("Speak Away en la web", #selector(openWebsite)))
        menu.addItem(item("Código en GitHub", #selector(openGitHub)))
        menu.addItem(item("Hecho por Martín Urbano · Open Source Everything", #selector(openInstagram)))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Salir de Speak Away", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        refreshStatus()
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func submenu(_ title: String, options: [(id: String, label: String)],
                         current: @escaping () -> String, choose: @escaping (String) -> Void) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu()
        for option in options {
            let entry = ClosureMenuItem(title: option.label) { [weak menu] in
                choose(option.id)
                menu?.items.forEach { $0.state = ($0 as? ClosureMenuItem)?.tag == option.id.hashValue ? .on : .off }
            }
            entry.tag = option.id.hashValue
            entry.state = current() == option.id ? .on : .off
            menu.addItem(entry)
        }
        parent.submenu = menu
        return parent
    }

    private func refreshStatus() {
        let missing = Permission.allCases.filter { !$0.granted }.map(\.title)
        switch engine.state {
        case .idle, .loading: statusLine.title = "Preparando el modelo…"
        case .downloading(let p): statusLine.title = "Descargando el modelo: \(Int(p * 100)) %"
        case .failed(let message): statusLine.title = "Error del modelo: \(message)"
        case .ready:
            statusLine.title = missing.isEmpty
                ? "Listo. Toca Fn dos veces para dictar"
                : "Falta permiso: " + missing.joined(separator: ", ")
        }
    }

    @objc private func openWelcome() { showWelcome() }
    @objc private func openHome() { showHome() }

    private func showHome() {
        if home == nil {
            home = HubWindow(stores: HubStores(stats: stats, history: history, scratchpad: scratchpad), engine: engine, openPermissions: { [weak self] in self?.showWelcome() })
        }
        NSApp.activate(ignoringOtherApps: true)
        home?.makeKeyAndOrderFront(nil)
    }
    @objc private func openWebsite() { NSWorkspace.shared.open(Settings.website) }
    @objc private func openGitHub() { NSWorkspace.shared.open(Settings.github) }
    @objc private func openInstagram() { NSWorkspace.shared.open(Settings.instagram) }

    private func showWelcome() {
        if welcome == nil {
            welcome = WelcomeWindow(engine: engine) { [weak self] in
                Settings.welcomed = true
                self?.welcome?.close()
                self?.showHome()
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        welcome?.makeKeyAndOrderFront(nil)
    }
}

/// A menu item that runs a closure, for the small option lists.
final class ClosureMenuItem: NSMenuItem {
    private let run: () -> Void

    init(title: String, run: @escaping () -> Void) {
        self.run = run
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError("not used") }

    @objc private func fire() { run() }
}
