import AVFoundation
import Combine
import Foundation
import SpeakAwayCore

/// How loud the room is and how long the meeting has run, on their own object so the level bars and the clock
/// redraw ten times and once a second without the transcript redrawing with them.
@MainActor
final class MeterModel: ObservableObject {
    @Published var level = 0.0
    /// Whole seconds spent recording, without the pauses.
    @Published var elapsed: TimeInterval = 0
}

/// Records a meeting with the iPhone's microphone and writes it down on the phone, live.
///
/// One microphone hears the whole room, so the notes have no "me" and "them": they are paragraphs with their time.
/// Everything said is appended to a journal file as it settles, so a crash or a restart loses nothing; the audio
/// itself is never kept. A call, Siri or an alarm pauses the meeting (with a note in the transcript) and it carries on
/// by itself when the system gives the microphone back. When the meeting stops it is saved, and summarized on the
/// phone when Apple Intelligence can do it.
///
/// The decisions (what a pause or a call does, when to summarize) live in Core and are tested there; this class only
/// carries them out, one event at a time.
@MainActor
final class MeetingRecorder: ObservableObject {
    enum Stage: Equatable {
        case idle
        /// Getting the speech model and the microphone ready.
        case preparing
        case recording
        case paused
        /// Stopped: the last words are being written down and the note is being saved.
        case finishing
    }

    /// A made-up meeting for the preview screens.
    struct Snapshot {
        var stage: Stage
        var title: String
        var defaultTitle: String
        var transcript: LiveTranscript
        var level: Double
        var elapsed: TimeInterval
    }

    @Published private(set) var stage: Stage = .idle
    /// The words so far, with the engine's current guess in `volatile`.
    @Published private(set) var transcript = LiveTranscript()
    /// What the user typed as the name of the meeting. Empty: it gets `defaultTitle`.
    @Published var title = ""
    /// The name the meeting gets when none is typed.
    @Published private(set) var defaultTitle = ""
    /// 0...1 while the speech model downloads, `nil` otherwise.
    @Published private(set) var speechProgress: Double?
    /// Why the meeting could not start or had to pause, in the language of the phone.
    @Published private(set) var problem: String?
    /// The problem is fixed in the Settings app (the microphone was turned off).
    @Published private(set) var problemNeedsSettings = false
    /// The meeting being summarized right now.
    @Published private(set) var summarizing: UUID?
    /// The note saved when the last meeting ended, for the screen that moves on to it. `nil`: nothing was kept.
    @Published private(set) var lastSaved: UUID?
    /// A short message for a toast. Cleared by the toast itself.
    @Published var notice: String?

    /// The loudness and the clock, for the bars and the counter.
    let meter = MeterModel()

    /// The name written for the meeting app in the notes of a call. A recording made here is of the room.
    static let appName = "iPhone"

    private let session: SessionController
    private let store: PhoneStore
    private let brain: OnDeviceBrain
    private let speech: MeetingSpeech
    private let now: () -> Date
    private let makeMic: () -> MeetingMic

    private let gate = CaptureGate()
    private var mic: MeetingMic?
    private var listener: MeetingListener?
    private var journal: MeetingJournalFile?
    private var phase = MeetingPhase.idle
    private var clock: MeetingClock?
    private var events: AsyncStream<MeetingEvent>.Continuation?
    private var loop: Task<Void, Never>?
    private var startTask: Task<Void, Never>?
    private var ticker: Timer?
    private var smoother = LevelSmoother()
    private var stopWaiters: [CheckedContinuation<UUID?, Never>] = []
    /// Tells a start that is still going on that it was cancelled or replaced.
    private var run = UUID()
    private var meetingID = UUID()
    private var startedAt = Date()
    private var locale = Locale(identifier: SpeechLocale.fallback)
    private var journaledTitle = ""

    init(session: SessionController, store: PhoneStore, brain: OnDeviceBrain = .live, speech: MeetingSpeech = MeetingSpeech(),
         now: @escaping () -> Date = Date.init, makeMic: @escaping () -> MeetingMic = { MeetingMic() }) {
        self.session = session
        self.store = store
        self.brain = brain
        self.speech = speech
        self.now = now
        self.makeMic = makeMic
    }

    /// A meeting is in the making, on, paused or being saved: the microphone is not free for anything else.
    var isActive: Bool { stage != .idle }

    /// The name shown for the meeting: what was typed, or the default.
    var shownTitle: String {
        let typed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return typed.isEmpty ? defaultTitle : typed
    }

    /// What the on-device model can do now, for the words of the summary card.
    func brainStatus() -> BrainAvailability { brain.availability() }

    private var english: Bool { !UILanguage.isSpanish }

    // MARK: Start

    /// Starts a meeting. Returns `false` when one is already going (`problem` says why when something else is wrong).
    @discardableResult
    func begin() -> Bool {
        guard stage == .idle else { return false }
        problem = nil
        problemNeedsSettings = false
        notice = nil
        lastSaved = nil
        let thisRun = UUID()
        run = thisRun
        meetingID = UUID()
        transcript = LiveTranscript()
        title = ""
        meter.elapsed = 0
        meter.level = 0
        smoother = LevelSmoother()
        defaultTitle = MeetingTitle.resolved("", startedAt: now(), english: english)
        stage = .preparing
        startTask = Task { await self.start(run: thisRun) }
        return true
    }

    private func start(run thisRun: UUID) async {
        let settings = store.settings
        let resolved = await speech.resolveLocale(setting: settings.language)
        guard run == thisRun else { return }
        locale = resolved
        do {
            try await speech.prepare(locale: resolved) { fraction in
                Task { @MainActor [weak self] in
                    guard let self, self.run == thisRun, self.stage == .preparing else { return }
                    self.speechProgress = fraction >= 1 ? nil : fraction
                }
            }
        } catch {
            return failStart(thisRun, error)
        }
        guard run == thisRun else { return }
        speechProgress = nil

        // From here the microphone is a meeting's: a dictation session, if one is running, ends.
        guard session.beginMeeting() else {
            return failStart(thisRun, AudioInputError.cannotStart("busy"))
        }

        let listener = speech.listen(
            locale: resolved,
            onPhrase: { [weak self] phrase in await self?.heard(phrase) },
            onFailure: { [weak self] error in Task { @MainActor in self?.speechFailed(error) } })
        let gate = self.gate
        gate.open { buffer in listener.feed(buffer) }

        let mic = makeMic()
        mic.preferredInputUID = settings.microphone
        mic.onEvent = { [weak self] event in MainActor.assumeIsolated { self?.micEvent(event) } }
        do {
            try await mic.start { buffer in gate.offer(buffer) }
        } catch {
            gate.close()
            await listener.cancel()
            session.endMeeting()
            return failStart(thisRun, error)
        }
        guard run == thisRun else {
            // Cancelled while the microphone was starting: give back what was taken.
            mic.stop()
            gate.close()
            await listener.cancel()
            session.endMeeting()
            return
        }

        self.mic = mic
        self.listener = listener
        startedAt = now()
        clock = MeetingClock(startedAt: startedAt)
        defaultTitle = MeetingTitle.resolved("", startedAt: startedAt, english: english)
        journaledTitle = MeetingTitle.resolved(title, startedAt: startedAt, english: english)
        journal = MeetingJournalFile(
            folder: store.folder.appendingPathComponent("Meetings", isDirectory: true),
            header: MeetingJournal.Header(id: meetingID, startedAt: startedAt, app: Self.appName, title: journaledTitle))
        phase = MeetingFlow.step(.idle, .startRequested).phase
        stage = .recording
        session.meetingPaused(false)
        startTicker()

        let (stream, continuation) = AsyncStream<MeetingEvent>.makeStream()
        events = continuation
        loop = Task { await self.runLoop(stream) }
    }

    /// The start did not work: say why and go back to idle.
    private func failStart(_ thisRun: UUID, _ error: Error) {
        guard run == thisRun else { return }
        speechProgress = nil
        problem = PhoneText.meetingReason(for: error)
        problemNeedsSettings = PhoneText.needsSettings(error)
        stage = .idle
    }

    // MARK: What the user does

    func pause() {
        if stage == .recording { send(.pauseRequested) }
    }

    func resume() {
        if stage == .paused { send(.resumeRequested) }
    }

    func togglePause() {
        if stage == .recording { pause() } else { resume() }
    }

    /// Stops the meeting, saves it and returns its id once it is on disk (`nil`: nothing was said, or it was cancelled
    /// before it began).
    @discardableResult
    func stop() async -> UUID? {
        switch stage {
        case .idle:
            return nil
        case .preparing:
            cancelStart()
            return nil
        case .recording, .paused:
            send(.stopRequested)
            return await withCheckedContinuation { stopWaiters.append($0) }
        case .finishing:
            return await withCheckedContinuation { stopWaiters.append($0) }
        }
    }

    /// The user gave up before the first word. Whatever the start had already taken, it gives back when it notices.
    private func cancelStart() {
        run = UUID()
        startTask?.cancel()
        startTask = nil
        speechProgress = nil
        stage = .idle
    }

    /// Keeps the name the user typed, so even a crash brings the meeting back with it.
    func commitTitle() {
        guard stage == .recording || stage == .paused else { return }
        let resolved = MeetingTitle.resolved(title, startedAt: startedAt, english: english)
        guard resolved != journaledTitle else { return }
        journaledTitle = resolved
        journal?.append(.title(resolved))
    }

    // MARK: The meeting's events, one at a time

    private func send(_ event: MeetingEvent) {
        events?.yield(event)
    }

    private func runLoop(_ stream: AsyncStream<MeetingEvent>) async {
        for await event in stream {
            let step = MeetingFlow.step(phase, event)
            phase = step.phase
            for effect in step.effects {
                // A capture that could not start leaves the rest of the step undone: nothing resumed.
                guard await perform(effect) else { break }
            }
            if step.phase == .idle { break }
        }
    }

    /// Carries out one effect. `false`: it failed and the rest of the step should not run.
    private func perform(_ effect: MeetingEffect) async -> Bool {
        switch effect {
        case .beginCapture:
            do {
                try mic?.resume()
            } catch {
                captureFailed(error)
                return false
            }
            clock = clock?.resumed(at: now())
            stage = .recording
            problem = nil
            problemNeedsSettings = false
            session.meetingPaused(false)

        case .suspendCapture:
            mic?.pause()
            clock = clock?.paused(at: now())
            stage = .paused
            meter.level = 0
            smoother = LevelSmoother()
            session.meetingPaused(true)
            commitTitle()
            // The last sentence settles now, so it is on the disk before the meeting waits.
            await listener?.flush()

        case .restartCapture:
            do {
                try mic?.restart()
            } catch {
                captureFailed(error)
                return false
            }

        case .mark(let marker):
            addMarker(marker)

        case .finish:
            await finish()
        }
        return true
    }

    private func captureFailed(_ error: Error) {
        problem = PhoneText.meetingReason(for: error)
        problemNeedsSettings = PhoneText.needsSettings(error)
        send(.captureFailed)
    }

    private func micEvent(_ event: MeetingMic.Event) {
        switch event {
        case .interruptionBegan: send(.interruptionBegan)
        case .interruptionEnded(let shouldResume): send(.interruptionEnded(shouldResume: shouldResume))
        case .inputChanged: send(.microphoneChanged)
        case .failed(let error): captureFailed(error)
        }
    }

    /// The engine stopped working in the middle of the meeting: keep what was said and save it.
    private func speechFailed(_ error: Error) {
        guard stage == .recording || stage == .paused else { return }
        problem = PhoneText.meetingReason(for: error)
        problemNeedsSettings = false
        Task { await stop() }
    }

    // MARK: The words

    /// A result of the speech engine. Settled sentences go to the journal at once.
    private func heard(_ phrase: RecognizedPhrase) {
        guard stage == .recording || stage == .paused || stage == .finishing else { return }
        transcript = transcript.applying(phrase)
        if phrase.isFinal, !phrase.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            journal?.append(.phrase(phrase))
        }
    }

    private func addMarker(_ marker: MeetingMarker) {
        let text = marker.text(english: english)
        let at = listener?.fedSeconds ?? 0
        transcript = transcript.appendingMarker(text, at: at)
        journal?.append(.marker(start: at, text: text))
    }

    // MARK: Finishing

    private func finish() async {
        commitTitle()
        stage = .finishing
        stopTicker()
        gate.close()
        mic?.onEvent = nil
        mic?.stop()
        mic = nil
        meter.level = 0
        clock = clock?.paused(at: now())
        let fed = listener?.fedSeconds ?? 0
        await listener?.finish()
        listener = nil
        // A guess the engine never settled (it stopped working) is still what was said: keep it.
        if let last = transcript.unsettledPhrase(endingAt: fed) { heard(last) }
        events?.finish()
        events = nil

        let lines = transcript.lines
        let recorded = clock?.elapsed(at: now()) ?? 0
        let lastLine = lines.map(\.start).max() ?? 0
        let endedAt = startedAt.addingTimeInterval(max(recorded, lastLine))
        let language = SpeechLocale.languageCode(locale.identifier)

        var savedID: UUID?
        var message: String?
        if lines.contains(where: { $0.speaker == .room }) {
            let meeting = Meeting(id: meetingID, title: MeetingTitle.resolved(title, startedAt: startedAt, english: english),
                                  app: Self.appName, startedAt: startedAt, endedAt: endedAt, lines: lines)
            if store.saveMeeting(meeting) {
                journal?.remove()
                savedID = meeting.id
            } else {
                // The journal stays: the words come back as a note the next time the app opens.
                message = String(localized: "The note could not be saved, but the words are kept and come back when you open the app.")
            }
        } else {
            journal?.remove()
            // When the meeting stopped on a problem, that is why nothing was said.
            message = problem ?? String(localized: "Nothing was said, so no note was saved.")
        }
        // Why a meeting ended early is told with the note: the recording screen is about to move on.
        notice = message ?? problem
        problem = nil
        problemNeedsSettings = false
        journal = nil
        session.endMeeting()
        clock = nil
        transcript = LiveTranscript()
        meter.elapsed = 0
        phase = .idle
        run = UUID()
        lastSaved = savedID
        stage = .idle

        // The notes start being written before the screen moves to the saved meeting, so it opens on "Summarizing".
        var writesSummary = false
        if let savedID, let saved = store.meeting(savedID), summaryPlan(for: saved).runsOnStop {
            summarizing = savedID
            writesSummary = true
        }

        let waiters = stopWaiters
        stopWaiters = []
        for waiter in waiters { waiter.resume(returning: savedID) }

        if writesSummary, let savedID {
            Task { await writeSummary(savedID, language: language) }
        }
    }

    // MARK: Summary

    /// What to do about the summary of a meeting, from what was said and what this iPhone can do.
    func summaryPlan(for meeting: Meeting) -> SummaryPlan {
        SummaryPlan.decide(lines: meeting.lines, brainOn: store.settings.polish, availability: brain.availability())
    }

    /// Writes the notes of a saved meeting (summary, decisions, tasks, open questions) with the on-device model and
    /// saves them with it. Without `language` the model answers in the language of the text.
    func summarize(_ id: UUID, language: String? = nil) async {
        guard summarizing == nil else { return }
        summarizing = id
        await writeSummary(id, language: language)
    }

    /// The work of `summarize`, with `summarizing` already set to `id` by the caller. Clears it when done.
    private func writeSummary(_ id: UUID, language: String?) async {
        defer { summarizing = nil }
        guard let meeting = store.meeting(id) else { return }
        let status = brain.availability()
        guard status.isUsable else {
            notice = PhoneText.brainSettingsDetail(status)
            return
        }
        do {
            let notes = try await brain.summarize(MeetingTranscript.text(for: meeting.lines), language).cleaned()
            guard !notes.isEmpty else { throw BrainError.failed("empty") }
            // The meeting may have been renamed or deleted while the model worked: save onto the current one.
            guard let current = store.meeting(id) else { return }
            store.saveMeeting(current.withSummary(notes.markdown(english: english)))
        } catch {
            notice = String(localized: "The summary could not be made. Try again.")
        }
    }

    // MARK: Clock

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard stage == .recording || stage == .paused else { return }
        if stage == .recording {
            smoother = smoother.updated(with: gate.currentLevel)
            meter.level = smoother.value
        }
        let seconds = (clock?.elapsed(at: now()) ?? 0).rounded(.down)
        if seconds != meter.elapsed { meter.elapsed = seconds }
    }

    // MARK: Preview

    /// Shows a made-up meeting for the preview screens: nothing is recorded or written.
    func showPreview(_ snapshot: Snapshot) {
        stage = snapshot.stage
        title = snapshot.title
        defaultTitle = snapshot.defaultTitle
        transcript = snapshot.transcript
        meter.elapsed = snapshot.elapsed
        meter.level = snapshot.level
    }
}

// MARK: Words for a recording

extension PhoneText {
    /// Like `reason(for:)`, with the words of a recording where a dictation would say something else.
    static func meetingReason(for error: Error) -> String {
        if let error = error as? AudioInputError, error == .microphoneDenied {
            return String(localized: "Microphone access is off. Allow it in Settings to record.")
        }
        if let error = error as? MeetingSpeech.Failure, error == .notAvailable {
            return String(localized: "Live transcription is not available on this iPhone.")
        }
        return reason(for: error)
    }
}
