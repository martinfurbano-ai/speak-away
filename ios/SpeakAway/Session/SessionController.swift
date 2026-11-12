import AVFoundation
import Combine
import Foundation
import SpeakAwayCore

/// The session on the phone. While it is running the microphone stays on so the app is not suspended;
/// what the mic hears is dropped unless the keyboard asked for a dictation. It listens for the keyboard's
/// requests, records, transcribes with the on-device engine, runs the same text path as the Mac, and
/// publishes its state to the shared folder for the keyboard.
@MainActor
final class SessionController: ObservableObject {
    @Published private(set) var state: SessionState = .idle
    /// When the session ends by itself (`nil`: when the user stops it).
    @Published private(set) var sessionEnd: Date?
    /// 0...1 while the speech model downloads, `nil` otherwise.
    @Published private(set) var speechProgress: Double?
    /// Why the session did not start, or the last thing that went wrong. Cleared when a session starts.
    @Published private(set) var problem: String?
    /// The speech model for the session's language is on the phone, so a dictation can start.
    @Published private(set) var speechReady = false
    /// The system's own words for the last failure, for the self test and bug reports. Not shown to the user.
    private(set) var lastErrorDetail: String?

    private struct Dictation {
        let id = UUID()
        let stream: TranscriptionStream?
        let field: FieldContext
        /// The text a spoken instruction applies to (Command Mode), else `nil`.
        let commandTarget: String?
    }

    private let files: SessionFiles
    private let stores: SharedStores
    private let transcriber: Transcriber
    private let makeInput: () -> AudioInput
    private let brain: OnDeviceBrain
    private let now: () -> Date

    private let gate = CaptureGate()
    private var input: AudioInput?
    private var observer: DarwinObserver?
    private var clock: Timer?
    private var levelTimer: Timer?
    private var dictation: Dictation?
    private var smoother = LevelSmoother()
    private var publishedAt = Date.distantPast
    private var publishedCommand = false
    private var lastRequest: UUID?
    private var speechLocale = Locale(identifier: SpeechLocale.fallback)
    private var starting = false

    /// Requests older than this are ignored: they belong to a moment that has passed.
    static let requestMaxAge: TimeInterval = 10

    init(files: SessionFiles = SessionFiles(), stores: SharedStores = SharedStores(), transcriber: Transcriber = AppleSpeech(),
         brain: OnDeviceBrain = .live, now: @escaping () -> Date = Date.init, makeInput: @escaping () -> AudioInput = { MicInput() }) {
        self.files = files
        self.stores = stores
        self.transcriber = transcriber
        self.brain = brain
        self.now = now
        self.makeInput = makeInput
        // A state left by an earlier run must not make the keyboard think a session is alive.
        if let leftover = files.readState(), leftover.state != .idle {
            files.write(state: .idle, at: now())
        }
    }

    var isActive: Bool { input != nil }

    // MARK: Session

    /// Starts the session (the mic stays ready) or, if one is running, restarts its clock. Safe to call twice.
    func startSession() async {
        if input != nil {
            extendSession()
            return
        }
        guard !starting else { return }
        starting = true
        defer { starting = false }
        problem = nil
        lastErrorDetail = nil

        let settings = stores.settings()
        let source = makeInput()
        source.onEvent = { [weak self] event in
            Task { @MainActor in self?.inputEvent(event) }
        }
        do {
            let gate = self.gate
            try await source.start { buffer in gate.offer(buffer) }
        } catch {
            source.stop()
            let reason = PhoneText.reason(for: error)
            problem = reason
            lastErrorDetail = String(describing: error)
            publish(.failed(reason: reason))
            return
        }
        input = source
        lastRequest = files.readRequest()?.id   // anything already in the file is old news
        speechLocale = await transcriber.resolveLocale(setting: settings.language)

        let started = now()
        sessionEnd = SessionPolicy(length: settings.sessionLength).expiry(from: started)
        observer = DarwinObserver(name: SessionChannel.requestNotification) { [weak self] in
            MainActor.assumeIsolated { self?.requestArrived() }
        }
        clock = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        publish(readyState)
        prepareSpeech()
    }

    /// The user stopped it, or the time ran out, or the mic was lost.
    func endSession() {
        levelTimer?.invalidate()
        levelTimer = nil
        clock?.invalidate()
        clock = nil
        observer?.stop()
        observer = nil
        gate.close()
        if let running = dictation {
            dictation = nil
            Task { await running.stream?.cancel() }
        }
        input?.stop()
        input = nil
        sessionEnd = nil
        speechProgress = nil
        speechReady = false
        publish(.idle)
    }

    private func extendSession() {
        let settings = stores.settings()
        sessionEnd = SessionPolicy(length: settings.sessionLength).expiry(from: now())
        if case .ready = state { publish(readyState) }
    }

    private var readyState: SessionState { .ready(until: sessionEnd) }

    // MARK: Requests from the keyboard

    private func requestArrived() {
        guard let request = files.readRequest(), request.id != lastRequest else { return }
        lastRequest = request.id
        guard now().timeIntervalSince(request.sentAt) <= Self.requestMaxAge else { return }
        perform(SessionDispatch.intent(for: request.message, in: state), field: request.field)
    }

    /// Carries out what the keyboard asked. Public for the self test, which plays the keyboard.
    func perform(_ intent: SessionDispatch.Intent, field: FieldContext) {
        switch intent {
        case .beginDictation: beginRecording(field: field, commandTarget: nil)
        case .beginCommand(let target): beginRecording(field: field, commandTarget: target)
        case .finish: finishRecording()
        case .cancel: cancelRecording()
        case .runCommand(let instruction, let target): runWrittenCommand(instruction: instruction, on: target, field: field)
        case .ignore: break
        }
    }

    // MARK: Recording

    private func beginRecording(field: FieldContext, commandTarget: String?) {
        guard input != nil, dictation == nil else { return }
        // The very first session downloads the speech model for the language; say so instead of recording into nothing.
        guard speechProgress == nil else {
            publish(.failed(reason: "Still getting the speech model ready. Try again in a moment."))
            return
        }
        let stream = transcriber.startStream(locale: speechLocale)
        dictation = Dictation(stream: stream, field: field, commandTarget: commandTarget)
        gate.open { buffer in stream.feed(buffer) }
        smoother = LevelSmoother()
        publish(.recording(level: 0), command: commandTarget != nil)
        levelTimer?.invalidate()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.publishLevel() }
        }
    }

    private func publishLevel() {
        guard case .recording = state, let running = dictation else { return }
        smoother = smoother.updated(with: gate.currentLevel)
        publish(.recording(level: smoother.value), command: running.commandTarget != nil)
    }

    private func finishRecording() {
        guard let running = dictation, case .recording = state else { return }
        levelTimer?.invalidate()
        levelTimer = nil
        let stats = gate.close()
        publish(.transcribing, command: running.commandTarget != nil)
        Task { await complete(running, stats: stats) }
    }

    private func cancelRecording() {
        guard let running = dictation, case .recording = state else { return }
        levelTimer?.invalidate()
        levelTimer = nil
        gate.close()
        dictation = nil
        Task { await running.stream?.cancel() }
        publish(readyState)
    }

    // MARK: Text path

    private func complete(_ running: Dictation, stats: CaptureStats) async {
        guard stats.verdict == .speech else {
            // Too short or silent: nothing to type, as on the Mac.
            await running.stream?.cancel()
            return settle(running)
        }
        let transcript: String
        do {
            transcript = try await running.stream?.finish() ?? ""
        } catch {
            return fail(running, error)
        }
        guard dictation?.id == running.id else { return }

        let settings = stores.settings()
        let language = settings.pipelineLanguage(resolvedLocale: speechLocale.identifier)

        if let target = running.commandTarget {
            let instruction = SpeechGate.clean(transcript).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !instruction.isEmpty else { return settle(running) }
            await applyCommand(instruction, on: target, language: language, running: running)
            return
        }

        guard let prepared = DictationFlow.prepare(transcript: transcript, language: language, field: running.field,
                                                   dictionary: stores.dictionary(), snippets: stores.snippets(),
                                                   styles: stores.styles(), autoEdit: settings.autoEdit) else {
            return settle(running)
        }
        var text = prepared.text
        if settings.polish, brain.availability().isUsable {
            let polished = await brain.polish(prepared.text, prepared.style.rawValue, language)
            guard dictation?.id == running.id else { return }
            text = DictationFlow.polished(polished, replacing: prepared)
        }
        do { try stores.recordDictation(text: text, raw: prepared.raw, seconds: stats.seconds, at: now()) } catch {}
        dictation = nil
        publish(.done(id: UUID(), text: text))
    }

    private func runWrittenCommand(instruction: String, on target: String, field: FieldContext) {
        guard input != nil, dictation == nil else { return }
        let running = Dictation(stream: nil, field: field, commandTarget: target)
        dictation = running
        publish(.transcribing, command: true)
        let language = stores.settings().pipelineLanguage(resolvedLocale: speechLocale.identifier)
        Task { await applyCommand(instruction, on: target, language: language, running: running) }
    }

    private func applyCommand(_ instruction: String, on target: String, language: String?, running: Dictation) async {
        let status = brain.availability()
        guard status.isUsable else { return fail(running, BrainError.unavailable(status)) }
        do {
            let result = try await brain.command(instruction, target, language)
            guard dictation?.id == running.id else { return }
            dictation = nil
            publish(.done(id: UUID(), text: result), command: true)
        } catch {
            fail(running, error)
        }
    }

    private func fail(_ running: Dictation, _ error: Error) {
        guard dictation?.id == running.id else { return }
        dictation = nil
        lastErrorDetail = String(describing: error)
        publish(.failed(reason: PhoneText.reason(for: error)))
    }

    /// Nothing to insert: back to ready.
    private func settle(_ running: Dictation) {
        guard dictation?.id == running.id else { return }
        dictation = nil
        publish(readyState)
    }

    // MARK: Clock

    private func tick() {
        switch SessionTick.decide(state: state, publishedAt: publishedAt, sessionEnd: sessionEnd, now: now()) {
        case .none: break
        case .heartbeat: publish(state, command: publishedCommand, notify: false)
        case .settle: publish(readyState)
        case .expire: endSession()
        }
    }

    // MARK: Input events

    private func inputEvent(_ event: AudioInputEvent) {
        guard input != nil else { return }
        switch event {
        case .interrupted:
            problem = "Another app or a call took the microphone, so the session ended."
        case .failed(let error):
            problem = PhoneText.reason(for: error)
            lastErrorDetail = String(describing: error)
        }
        endSession()
    }

    // MARK: Speech model

    private func prepareSpeech() {
        let locale = speechLocale
        Task {
            do {
                try await transcriber.prepare(locale: locale) { fraction in
                    Task { @MainActor [weak self] in self?.speechProgress = fraction >= 1 ? nil : fraction }
                }
                speechProgress = nil
                speechReady = input != nil
            } catch {
                speechProgress = nil
                problem = PhoneText.reason(for: error)
                lastErrorDetail = String(describing: error)
            }
        }
    }

    // MARK: Publishing

    private func publish(_ newState: SessionState, command: Bool = false, notify: Bool = true) {
        state = newState
        publishedAt = now()
        publishedCommand = command
        files.write(state: newState, at: publishedAt, command: command)
        if notify { DarwinNotifier.post(SessionChannel.stateNotification) }
    }
}
