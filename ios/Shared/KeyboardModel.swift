import SwiftUI
import UIKit
import SpeakAwayCore

/// What the model needs from the keyboard's view controller: the text field, the system's own keys, and the app.
@MainActor
protocol KeyboardHost: AnyObject {
    var proxy: UITextDocumentProxy { get }
    var hasFullAccess: Bool { get }
    var needsGlobeKey: Bool { get }
    /// Opens the Speak Away app with this URL (a keyboard cannot call `UIApplication.open` directly).
    func open(_ url: URL)
}

/// Everything the keyboard knows and does between the keys and the text field. The app does the listening and
/// the writing; the keyboard sends it requests through `SessionClient`, shows the state it publishes, and puts
/// the finished text into the field. No audio, speech or model code lives here: an extension has little memory.
@MainActor
final class KeyboardModel: ObservableObject {
    // MARK: What the view shows

    @Published private(set) var state: SessionState = .idle
    /// The recording or result on screen belongs to Command Mode.
    @Published private(set) var commandActive = false
    @Published private(set) var styleOverride: WritingStyle?
    @Published private(set) var effectiveStyle: WritingStyle = .casual
    @Published private(set) var hasFullAccess = false
    @Published private(set) var needsGlobe = false
    @Published private(set) var returnTitle = String(localized: "return")
    /// The return key is the plain one (not Go, Search, Send...).
    @Published private(set) var returnIsPlain = true
    @Published private(set) var canUndo = false
    /// A short message under the keys (Command Mode with nothing to rewrite, for example). Clears itself.
    @Published private(set) var hint: String?

    // MARK: Collaborators

    private weak var host: KeyboardHost?
    private let client: SessionClient
    private let stores: SharedStores
    private let now: () -> Date

    private var gesture = MicGesture()
    private var commandTarget: CommandTarget?
    private var lastInsertion: LastInsertion?
    private var clock: Timer?
    private var hintClear: Task<Void, Never>?
    private var micIsDown = false

    init(host: KeyboardHost, client: SessionClient = SessionClient(), stores: SharedStores = SharedStores(),
         now: @escaping () -> Date = Date.init) {
        self.host = host
        self.client = client
        self.stores = stores
        self.now = now
    }

    /// A keyboard that only shows a state, for the app's preview screens: no text field, no app, and every file it
    /// could touch lives in `folder`, never in the real shared folder.
    init(preview state: SessionState, folder: URL, command: Bool = false, effective: WritingStyle = .casual,
         canUndo: Bool = false, now: @escaping () -> Date = Date.init) {
        self.host = nil
        self.client = SessionClient(files: SessionFiles(folder: folder))
        self.stores = SharedStores(folder: folder)
        self.now = now
        self.state = state
        self.commandActive = command
        self.effectiveStyle = effective
        self.hasFullAccess = true
        self.needsGlobe = true
        self.canUndo = canUndo
    }

    // MARK: Lifecycle

    /// The keyboard is on screen: listen for the app, check the state, take a result that arrived meanwhile.
    func start() {
        client.observe { [weak self] in
            MainActor.assumeIsolated { self?.appPublished() }
        }
        clock?.invalidate()
        // A killed app stops refreshing its state; this notices within a couple of seconds.
        clock = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
        deliverPendingResult()
    }

    func stop() {
        client.stopObserving()
        clock?.invalidate()
        clock = nil
    }

    /// The text field changed (another field, or the text moved): what the keys do may depend on it.
    func fieldChanged() {
        refresh()
    }

    private func appPublished() {
        refresh()
        deliverPendingResult()
    }

    /// Reads everything the view depends on. Cheap enough to call often.
    func refresh() {
        guard let host else { return }
        hasFullAccess = host.hasFullAccess
        needsGlobe = host.needsGlobeKey
        let returnKey: UIReturnKeyType? = host.proxy.returnKeyType
        returnTitle = Self.returnTitle(for: returnKey)
        returnIsPlain = Self.isPlainReturn(returnKey)
        guard hasFullAccess else {
            state = .idle
            commandActive = false
            canUndo = false
            return
        }
        let current = client.state
        state = current
        commandActive = client.record?.command ?? false
        gesture = gesture.following(current, at: now())
        effectiveStyle = field.style(in: stores.styles())
        canUndo = InsertionUndo.plan(for: lastInsertion, contextBeforeCursor: host.proxy.documentContextBeforeInput) != nil
    }

    // MARK: The field

    private var field: FieldContext {
        guard let proxy = host?.proxy else { return FieldContext(styleOverride: styleOverride) }
        // Both traits are optional requirements of the proxy protocol, so each can be nil twice over.
        let keyboard: UIKeyboardType? = proxy.keyboardType
        let content: UITextContentType?? = proxy.textContentType
        return FieldContext(keyboardType: keyboard?.rawValue ?? 0, contentType: content.flatMap { $0 }?.rawValue,
                            styleOverride: styleOverride)
    }

    private static func returnTitle(for type: UIReturnKeyType?) -> String {
        switch type {
        case .go?: return String(localized: "Go")
        case .search?, .google?, .yahoo?: return String(localized: "Search")
        case .send?: return String(localized: "Send")
        case .done?: return String(localized: "Done")
        case .next?: return String(localized: "Next")
        case .join?: return String(localized: "Join")
        case .route?: return String(localized: "Route")
        case .continue?: return String(localized: "Continue")
        case .emergencyCall?: return String(localized: "Call")
        default: return String(localized: "return")
        }
    }

    private static func isPlainReturn(_ type: UIReturnKeyType?) -> Bool {
        switch type {
        case .go?, .search?, .google?, .yahoo?, .send?, .done?, .next?, .join?, .route?, .continue?, .emergencyCall?: return false
        default: return true
        }
    }

    // MARK: Mic

    func micPressed() {
        guard !micIsDown else { return }
        micIsDown = true
        guard hasFullAccess else { return }
        let (next, action) = gesture.pressed(at: now(), state: client.state)
        gesture = next
        perform(action)
    }

    func micReleased() {
        guard micIsDown else { return }
        micIsDown = false
        guard hasFullAccess else { return }
        let (next, action) = gesture.released(at: now())
        gesture = next
        perform(action)
    }

    /// One tap for assistive technology: press and let go at once.
    func micTapped() {
        micPressed()
        micReleased()
    }

    private func perform(_ action: MicGesture.Action) {
        switch action {
        case .openApp:
            host?.open(SessionChannel.startURL)
        case .start:
            haptic(.medium)
            client.send(.start, field: field)
        case .stop:
            haptic(.light)
            client.send(.stop, field: field)
        case .none:
            break
        }
        refresh()
    }

    // MARK: Command Mode

    func wandTapped() {
        guard hasFullAccess, let host else { return }
        let current = client.state
        switch current {
        case .recording:
            // A command being spoken ends with a second tap. A dictation in progress is not interrupted by the wand.
            if client.record?.command == true {
                haptic(.light)
                client.send(.stop, field: field)
            }
        case .transcribing:
            break
        case .idle, .failed:
            host.open(SessionChannel.startURL)
        case .ready, .done:
            let proxy = host.proxy
            guard let target = CommandTarget.resolve(selectedText: proxy.selectedText,
                                                     documentContextBeforeInput: proxy.documentContextBeforeInput) else {
                show(String(localized: "Select some text, or write a sentence first, then tap the wand and say what to change."))
                return
            }
            commandTarget = target
            haptic(.medium)
            client.send(.startCommand(on: target.text), field: field)
        }
        refresh()
    }

    // MARK: Style chip

    var chipText: String { StyleText.chip(override: styleOverride, effective: effectiveStyle) }

    func chipTapped() {
        styleOverride = StyleOverride.next(after: styleOverride)
        haptic(.light)
        refresh()
    }

    // MARK: Results

    /// Puts the app's finished text into the field, once.
    func deliverPendingResult() {
        guard hasFullAccess, let host, let result = client.takePendingResult() else { return }
        let proxy = host.proxy
        if result.command {
            // Replace what the instruction was about; if this keyboard was created again meanwhile, look it up again.
            let target = commandTarget ?? CommandTarget.resolve(selectedText: proxy.selectedText,
                                                                documentContextBeforeInput: proxy.documentContextBeforeInput)
            commandTarget = nil
            if let target {
                for _ in 0..<target.deleteBackward { proxy.deleteBackward() }
                proxy.insertText(target.replacement(for: result.text))
                lastInsertion = .command(replacing: target, with: result.text)
            } else {
                proxy.insertText(result.text)
                lastInsertion = .dictation(result.text)
            }
        } else {
            proxy.insertText(result.text)
            lastInsertion = .dictation(result.text)
        }
        haptic(.light)
        refresh()
    }

    func undoTapped() {
        guard let proxy = host?.proxy,
              let step = InsertionUndo.plan(for: lastInsertion, contextBeforeCursor: proxy.documentContextBeforeInput) else { return }
        for _ in 0..<step.deleteBackward { proxy.deleteBackward() }
        if !step.insert.isEmpty { proxy.insertText(step.insert) }
        lastInsertion = nil
        haptic(.light)
        refresh()
    }

    // MARK: Plain keys

    func typeSpace() { host?.proxy.insertText(" "); refresh() }
    func typeReturn() { host?.proxy.insertText("\n"); refresh() }
    func deleteOnce() { host?.proxy.deleteBackward(); refresh() }

    func openSetup() {
        host?.open(SessionChannel.setupURL)
    }

    // MARK: Small things

    private func show(_ message: String) {
        hint = message
        hintClear?.cancel()
        hintClear = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.hint = nil
        }
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        // Haptics from a keyboard need Full Access, and the user can turn them off in the app.
        guard hasFullAccess, stores.settings().haptics else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
