import AVFoundation
import Speech
import SpeakAwayCore

/// The speech engine of a meeting: `SpeechAnalyzer` with a `SpeechTranscriber` (iOS 26), made for long speech in a room.
/// It reports a guess while a sentence is being said (volatile) and the sentence again once it has settled (final).
/// The audio never leaves the phone and none of it is kept: only the words come out.
final class MeetingSpeech {
    enum Failure: Error, Equatable {
        /// This iPhone cannot run the engine that meetings need.
        case notAvailable
    }

    func resolveLocale(setting: String) async -> Locale {
        let supported = await SpeechTranscriber.supportedLocales.map(\.identifier)
        let id = SpeechLocale.resolve(setting: setting, preferred: Locale.preferredLanguages, supported: supported)
        return Locale(identifier: id)
    }

    /// Makes sure everything needed to listen in `locale` is on this phone, installing it when missing.
    /// `progress` reports 0...1 while a download runs, from any thread.
    func prepare(locale: Locale, progress: @escaping @Sendable (Double) -> Void) async throws {
        guard SpeechTranscriber.isAvailable else { throw Failure.notAvailable }
        guard await SpeechTranscriber.supportedLocale(equivalentTo: locale) != nil else {
            throw TranscriberError.unsupportedLocale(locale.identifier)
        }
        let module = Self.makeModule(locale: locale)
        switch await AssetInventory.status(forModules: [module]) {
        case .installed:
            progress(1)
        case .unsupported:
            throw TranscriberError.unsupportedLocale(locale.identifier)
        case .supported, .downloading:
            guard let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) else {
                progress(1)
                break
            }
            let watcher = request.progress.observe(\.fractionCompleted, options: [.initial, .new]) { value, _ in
                progress(value.fractionCompleted)
            }
            defer { watcher.invalidate() }
            do {
                try await request.downloadAndInstall()
            } catch {
                throw TranscriberError.assetsUnavailable(String(describing: error))
            }
            progress(1)
        @unknown default:
            break
        }
        // Keeps the model on the phone for this app. Best effort: the limit is a few languages.
        _ = try? await AssetInventory.reserve(locale: locale)
    }

    /// Starts listening to one meeting. Audio can be fed at once; it waits until the engine is ready.
    /// `onPhrase` gets every result in order; `onFailure` is told once if the engine stops working.
    func listen(locale: Locale, onPhrase: @escaping MeetingListener.PhraseHandler,
                onFailure: @escaping @Sendable (Error) -> Void) -> MeetingListener {
        MeetingListener(transcriber: Self.makeModule(locale: locale), onPhrase: onPhrase, onFailure: onFailure)
    }

    /// Live guesses on, and the time of each result, so the words sit on the meeting's timeline.
    private static func makeModule(locale: Locale) -> SpeechTranscriber {
        SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [.volatileResults],
                          attributeOptions: [.audioTimeRange])
    }
}

/// One meeting being listened to. The audio thread only copies buffers into a queue; a task converts them to the format
/// the engine wants and feeds the analyzer, so the microphone callback never waits for the engine.
final class MeetingListener: @unchecked Sendable {
    typealias PhraseHandler = @Sendable (RecognizedPhrase) async -> Void

    private enum Item: @unchecked Sendable {
        case audio(AVAudioPCMBuffer)
        /// Settle what has been heard so far, then resume the waiter.
        case flush(CheckedContinuation<Void, Never>)
    }

    /// The longest `flush` waits for the settled form of the last sentence.
    private static let settleLimit: TimeInterval = 0.8
    /// The longest `finish` waits for the engine to hand over the last results.
    private static let finishLimit: Double = 10

    private let transcriber: SpeechTranscriber
    private let analyzer: SpeechAnalyzer
    private let items: AsyncStream<Item>
    private let itemsContinuation: AsyncStream<Item>.Continuation
    private let onPhrase: PhraseHandler
    private let onFailure: @Sendable (Error) -> Void

    private let lock = NSLock()
    private var fed: TimeInterval = 0
    private var guessPending = false
    private var ending = false
    private var failureReported = false
    private var feeder: Task<Void, Never>?
    private var consumer: Task<Void, Never>?

    init(transcriber: SpeechTranscriber, onPhrase: @escaping PhraseHandler, onFailure: @escaping @Sendable (Error) -> Void) {
        self.transcriber = transcriber
        self.onPhrase = onPhrase
        self.onFailure = onFailure
        analyzer = SpeechAnalyzer(modules: [transcriber],
                                  options: SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .whileInUse))
        let (stream, continuation) = AsyncStream<Item>.makeStream()
        items = stream
        itemsContinuation = continuation
        feeder = Task { [self] in await runFeeder() }
        consumer = Task { [self] in await runConsumer() }
    }

    /// Seconds of audio handed to the engine so far: the meeting's timeline, pauses left out. Markers are placed on it.
    var fedSeconds: TimeInterval {
        lock.lock(); defer { lock.unlock() }
        return fed
    }

    /// Adds audio in any format. Called from the audio thread; the buffer is copied.
    func feed(_ buffer: AVAudioPCMBuffer) {
        guard let copy = buffer.copied() else { return }
        let seconds = buffer.format.sampleRate > 0 ? Double(buffer.frameLength) / buffer.format.sampleRate : 0
        lock.lock(); fed += seconds; lock.unlock()
        itemsContinuation.yield(.audio(copy))
    }

    /// Settles what was heard up to now: the last sentence becomes final and is reported before this returns
    /// (or a moment later, if the engine is slow). Used when the meeting pauses.
    func flush() async {
        await withCheckedContinuation { (waiter: CheckedContinuation<Void, Never>) in
            if case .terminated = itemsContinuation.yield(.flush(waiter)) { waiter.resume() }
        }
        let deadline = Date().addingTimeInterval(Self.settleLimit)
        while hasGuessPending, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(40))
        }
    }

    /// No more audio: settles everything and reports the last results. Returns when the engine is done (or after a limit).
    func finish() async {
        markEnding()
        itemsContinuation.finish()
        await feeder?.value
        let watchdog = Task { [consumer] in
            try? await Task.sleep(for: .seconds(Self.finishLimit))
            consumer?.cancel()
        }
        await consumer?.value
        watchdog.cancel()
    }

    /// Throws the listening away.
    func cancel() async {
        markEnding()
        itemsContinuation.finish()
        feeder?.cancel()
        consumer?.cancel()
        await analyzer.cancelAndFinishNow()
    }

    // MARK: Audio in

    private func runFeeder() async {
        do {
            guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
                throw TranscriberError.noAudioFormat
            }
            try await analyzer.prepareToAnalyze(in: format)
            let (inputs, inputContinuation) = AsyncStream<AnalyzerInput>.makeStream()
            try await analyzer.start(inputSequence: inputs)

            let converter = BufferConverter(target: format)
            for await item in items {
                if Task.isCancelled { break }
                switch item {
                case .audio(let buffer):
                    if let converted = try converter.convert(buffer) {
                        inputContinuation.yield(AnalyzerInput(buffer: converted))
                    }
                case .flush(let waiter):
                    try? await analyzer.finalize(through: nil)
                    waiter.resume()
                }
            }
            inputContinuation.finish()
            if Task.isCancelled { throw CancellationError() }
            try await analyzer.finalizeAndFinishThroughEndOfInput()
        } catch {
            report(error)
            await analyzer.cancelAndFinishNow()
        }
        releaseWaiters()
    }

    /// Anyone still waiting for a flush when the feeder is gone must not wait for ever.
    private func releaseWaiters() {
        itemsContinuation.finish()
        Task { [items] in
            for await item in items {
                if case .flush(let waiter) = item { waiter.resume() }
            }
        }
    }

    // MARK: Results out

    private func runConsumer() async {
        var lastEnd: TimeInterval = 0
        do {
            for try await result in transcriber.results {
                let text = String(result.text.characters)
                let start = Self.seconds(result.range.start, fallback: lastEnd)
                let end = max(start, Self.seconds(result.range.end, fallback: start))
                let isFinal = result.isFinal
                lastEnd = max(lastEnd, end)
                setGuessPending(!isFinal && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                await onPhrase(RecognizedPhrase(text: text, start: start, end: end, isFinal: isFinal))
            }
        } catch {
            report(error)
        }
        setGuessPending(false)
    }

    private static func seconds(_ time: CMTime, fallback: TimeInterval) -> TimeInterval {
        let value = time.seconds
        return value.isFinite ? max(0, value) : fallback
    }

    // MARK: State shared by the tasks

    private var hasGuessPending: Bool {
        lock.lock(); defer { lock.unlock() }
        return guessPending
    }

    private func setGuessPending(_ value: Bool) {
        lock.lock(); guessPending = value; lock.unlock()
    }

    private func markEnding() {
        lock.lock(); ending = true; lock.unlock()
    }

    /// Tells the owner once that the engine stopped working. Nothing is reported while the listening is being closed.
    private func report(_ error: Error) {
        if error is CancellationError { return }
        lock.lock()
        let first = !ending && !failureReported
        failureReported = true
        lock.unlock()
        if first { onFailure(error) }
    }
}
