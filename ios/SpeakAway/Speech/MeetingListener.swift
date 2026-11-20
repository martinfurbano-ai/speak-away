import AVFoundation
import Speech
import SpeakAwayCore

/// Serializes candidate updates from the independent language result streams.
private actor MeetingSpeechResults {
    private var snapshots: [MeetingSpeechSnapshot]
    private let preferredLocale: String
    private let onSnapshot: MeetingListener.SnapshotHandler

    init(locales: [Locale], onSnapshot: @escaping MeetingListener.SnapshotHandler) {
        snapshots = locales.map { MeetingSpeechSnapshot(locale: $0.identifier) }
        preferredLocale = locales.first?.identifier ?? SpeechLocale.fallback
        self.onSnapshot = onSnapshot
    }

    func receive(_ phrase: RecognizedPhrase, candidate: SpeechCandidate) async {
        snapshots = snapshots.map {
            $0.locale == candidate.locale ? $0.applying(phrase, confidence: candidate.confidence) : $0
        }
        if let selected = selected() { await onSnapshot(selected) }
    }

    func selected() -> MeetingSpeechSnapshot? {
        guard let chosen = SpeechSelection.choose(snapshots.map(\.candidate), preferredLocale: preferredLocale) else { return nil }
        return snapshots.first { $0.locale == chosen.locale }
    }
}

/// Copies microphone buffers once and feeds both modules through one analyzer. Each candidate keeps its own
/// segmentation; callbacks replace the displayed transcript instead of mixing competing interpretations.
final class MeetingListener: @unchecked Sendable {
    typealias SnapshotHandler = @Sendable (MeetingSpeechSnapshot) async -> Void

    private enum Item: @unchecked Sendable {
        case audio(AVAudioPCMBuffer)
        case flush(CheckedContinuation<Void, Never>)
    }

    private static let settleLimit: TimeInterval = 0.8
    private static let finishLimit: Double = 10

    private let transcribers: [SpeechTranscriber]
    private let locales: [Locale]
    private let analyzer: SpeechAnalyzer
    private let results: MeetingSpeechResults
    private let items: AsyncStream<Item>
    private let itemsContinuation: AsyncStream<Item>.Continuation
    private let onFailure: @Sendable (Error) -> Void
    private let lock = NSLock()
    private var fed: TimeInterval = 0
    private var pendingLocales: Set<String> = []
    private var cancelled = false
    private var failureReported = false
    private var feeder: Task<Void, Never>?
    private var consumer: Task<Void, Never>?

    init(locales: [Locale], transcribers: [SpeechTranscriber], onSnapshot: @escaping SnapshotHandler,
         onFailure: @escaping @Sendable (Error) -> Void) {
        self.locales = locales
        self.transcribers = transcribers
        self.onFailure = onFailure
        results = MeetingSpeechResults(locales: locales, onSnapshot: onSnapshot)
        analyzer = SpeechAnalyzer(modules: transcribers,
                                  options: SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .whileInUse))
        let (stream, continuation) = AsyncStream<Item>.makeStream()
        items = stream
        itemsContinuation = continuation
        feeder = Task { [self] in await runFeeder() }
        consumer = Task { [self] in
            await withTaskGroup(of: Void.self) { group in
                for (locale, transcriber) in zip(locales, transcribers) {
                    group.addTask { await self.runConsumer(transcriber: transcriber, locale: locale.identifier) }
                }
            }
        }
    }

    var fedSeconds: TimeInterval {
        lock.lock(); defer { lock.unlock() }
        return fed
    }

    func feed(_ buffer: AVAudioPCMBuffer) {
        guard let copy = buffer.copied() else { return }
        let seconds = buffer.format.sampleRate > 0 ? Double(buffer.frameLength) / buffer.format.sampleRate : 0
        lock.lock(); fed += seconds; lock.unlock()
        itemsContinuation.yield(.audio(copy))
    }

    func flush() async {
        await withCheckedContinuation { (waiter: CheckedContinuation<Void, Never>) in
            if case .terminated = itemsContinuation.yield(.flush(waiter)) { waiter.resume() }
        }
        let deadline = Date().addingTimeInterval(Self.settleLimit)
        while hasGuessPending, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(40))
        }
    }

    /// Waits for both final candidate streams, including a language whose last result arrives later.
    @discardableResult
    func finish() async -> MeetingSpeechSnapshot? {
        itemsContinuation.finish()
        let watchdog = Task { [self] in
            try? await Task.sleep(for: .seconds(Self.finishLimit))
            guard !Task.isCancelled else { return }
            report(TranscriberError.assetsUnavailable("Meeting speech finalization timed out"))
            feeder?.cancel()
            consumer?.cancel()
            await analyzer.cancelAndFinishNow()
        }
        await feeder?.value
        await consumer?.value
        watchdog.cancel()
        return await results.selected()
    }

    func cancel() async {
        markCancelled()
        itemsContinuation.finish()
        feeder?.cancel()
        consumer?.cancel()
        await analyzer.cancelAndFinishNow()
        await feeder?.value
        await consumer?.value
    }

    private func runFeeder() async {
        do {
            guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: transcribers) else {
                throw TranscriberError.noAudioFormat
            }
            try await analyzer.prepareToAnalyze(in: format)
            let (inputs, inputContinuation) = AsyncStream<AnalyzerInput>.makeStream()
            defer { inputContinuation.finish() }
            try await analyzer.start(inputSequence: inputs)
            let converter = BufferConverter(target: format)
            for await item in items {
                if Task.isCancelled {
                    if case .flush(let waiter) = item { waiter.resume() }
                    break
                }
                switch item {
                case .audio(let buffer):
                    if let converted = try converter.convert(buffer) {
                        inputContinuation.yield(AnalyzerInput(buffer: converted))
                    }
                case .flush(let waiter):
                    do { try await analyzer.finalize(through: nil) } catch { report(error) }
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
        itemsContinuation.finish()
        for await item in items {
            if case .flush(let waiter) = item { waiter.resume() }
        }
    }

    private func runConsumer(transcriber: SpeechTranscriber, locale: String) async {
        var lastEnd: TimeInterval = 0
        do {
            for try await result in transcriber.results {
                let candidate = SpeechConfidence.candidate(text: result.text, locale: locale)
                let start = Self.seconds(result.range.start, fallback: lastEnd)
                let end = max(start, Self.seconds(result.range.end, fallback: start))
                lastEnd = max(lastEnd, end)
                setGuessPending(!result.isFinal && !candidate.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                locale: locale)
                await results.receive(RecognizedPhrase(text: candidate.text, start: start, end: end, isFinal: result.isFinal),
                                      candidate: candidate)
            }
        } catch {
            report(error)
        }
        setGuessPending(false, locale: locale)
    }

    private static func seconds(_ time: CMTime, fallback: TimeInterval) -> TimeInterval {
        let value = time.seconds
        return value.isFinite ? max(0, value) : fallback
    }

    private var hasGuessPending: Bool {
        lock.lock(); defer { lock.unlock() }
        return !pendingLocales.isEmpty
    }

    private func setGuessPending(_ value: Bool, locale: String) {
        lock.lock(); defer { lock.unlock() }
        pendingLocales = value ? pendingLocales.union([locale]) : pendingLocales.subtracting([locale])
    }

    private func markCancelled() {
        lock.lock(); cancelled = true; lock.unlock()
    }

    private func report(_ error: Error) {
        if error is CancellationError { return }
        lock.lock()
        let first = !cancelled && !failureReported
        failureReported = true
        lock.unlock()
        if first { onFailure(error) }
    }
}
