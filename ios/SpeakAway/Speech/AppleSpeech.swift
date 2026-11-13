import AVFoundation
import Speech
import SpeakAwayCore

/// Apple's on-device dictation engine (iOS 26): `SpeechAnalyzer` with a `DictationTranscriber`.
/// Audio never leaves the phone. The language model is installed once through `AssetInventory`.
final class AppleSpeech: Transcriber {
    func resolveLocale(setting: String) async -> Locale {
        let supported = await DictationTranscriber.supportedLocales.map(\.identifier)
        let id = SpeechLocale.resolve(setting: setting, preferred: Locale.preferredLanguages, supported: supported)
        return Locale(identifier: id)
    }

    func prepare(locale: Locale, progress: @escaping @Sendable (Double) -> Void) async throws {
        guard await DictationTranscriber.supportedLocale(equivalentTo: locale) != nil else {
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

    /// Where the speech model for this language stands on this phone, without downloading anything.
    static func modelState(for locale: Locale) async -> SpeechModelState {
        guard await DictationTranscriber.supportedLocale(equivalentTo: locale) != nil else { return .failed }
        switch await AssetInventory.status(forModules: [makeModule(locale: locale)]) {
        case .installed: return .installed
        case .supported: return .missing
        case .downloading: return .downloading(0)
        case .unsupported: return .failed
        @unknown default: return .unknown
        }
    }

    func startStream(locale: Locale) -> TranscriptionStream {
        AppleSpeechStream(transcriber: Self.makeModule(locale: locale))
    }

    /// Punctuation on, nothing else: the text pipeline does the rest.
    fileprivate static func makeModule(locale: Locale) -> DictationTranscriber {
        DictationTranscriber(locale: locale, contentHints: [], transcriptionOptions: [.punctuation],
                             reportingOptions: [], attributeOptions: [])
    }
}

/// One dictation. The audio thread only copies buffers into a queue; a task converts them to the
/// format the engine wants and feeds the analyzer, so the microphone callback never waits for it.
private final class AppleSpeechStream: TranscriptionStream {
    private let rawBuffers: AsyncStream<AVAudioPCMBuffer>
    private let rawContinuation: AsyncStream<AVAudioPCMBuffer>.Continuation
    private let analyzer: SpeechAnalyzer
    private var task: Task<String, Error>?

    init(transcriber: DictationTranscriber) {
        let (stream, continuation) = AsyncStream<AVAudioPCMBuffer>.makeStream()
        rawBuffers = stream
        rawContinuation = continuation
        analyzer = SpeechAnalyzer(modules: [transcriber],
                                  options: SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .lingering))
        let analyzer = self.analyzer
        task = Task { [rawBuffers] in
            try await Self.run(analyzer: analyzer, transcriber: transcriber, buffers: rawBuffers)
        }
    }

    func feed(_ buffer: AVAudioPCMBuffer) {
        guard let copy = buffer.copied() else { return }
        rawContinuation.yield(copy)
    }

    func finish() async throws -> String {
        rawContinuation.finish()
        guard let task else { return "" }
        return try await task.value
    }

    func cancel() async {
        rawContinuation.finish()
        task?.cancel()
        await analyzer.cancelAndFinishNow()
    }

    private static func run(analyzer: SpeechAnalyzer, transcriber: DictationTranscriber,
                            buffers: AsyncStream<AVAudioPCMBuffer>) async throws -> String {
        // Collects the finished phrases while the audio goes in.
        let collector = Task { () -> [String] in
            var pieces: [String] = []
            for try await result in transcriber.results where result.isFinal {
                pieces.append(String(result.text.characters))
            }
            return pieces
        }
        do {
            guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
                throw TranscriberError.noAudioFormat
            }
            try await analyzer.prepareToAnalyze(in: format)
            let (inputs, inputContinuation) = AsyncStream<AnalyzerInput>.makeStream()
            try await analyzer.start(inputSequence: inputs)

            let converter = BufferConverter(target: format)
            for await buffer in buffers {
                if Task.isCancelled { break }
                if let converted = try converter.convert(buffer) {
                    inputContinuation.yield(AnalyzerInput(buffer: converted))
                }
            }
            inputContinuation.finish()
            if Task.isCancelled { throw CancellationError() }
            try await analyzer.finalizeAndFinishThroughEndOfInput()
            return TranscriptJoiner.join(try await collector.value)
        } catch {
            collector.cancel()
            await analyzer.cancelAndFinishNow()
            throw error
        }
    }
}

/// Converts microphone buffers to the format the speech engine asked for. The converter is kept between
/// buffers (sample-rate conversion has state) and rebuilt if the input format changes, as on a route change.
private final class BufferConverter {
    private let target: AVAudioFormat
    private var converter: AVAudioConverter?

    init(target: AVAudioFormat) {
        self.target = target
    }

    func convert(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer? {
        if buffer.format == target { return buffer }
        if converter == nil || converter?.inputFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: target)
            converter?.primeMethod = .none
        }
        guard let converter else { throw TranscriberError.conversionFailed }
        let ratio = target.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { throw TranscriberError.conversionFailed }
        var fed = false
        var error: NSError?
        let status = converter.convert(to: out, error: &error) { _, inputStatus in
            if fed {
                inputStatus.pointee = .noDataNow
                return nil
            }
            fed = true
            inputStatus.pointee = .haveData
            return buffer
        }
        if status == .error || error != nil { throw TranscriberError.conversionFailed }
        return out.frameLength > 0 ? out : nil
    }
}

extension AVAudioPCMBuffer {
    /// A copy that owns its samples, for audio that is used after the callback that delivered it returns.
    func copied() -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else { return nil }
        copy.frameLength = frameLength
        let source = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: audioBufferList))
        let destination = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        for index in 0..<min(source.count, destination.count) {
            guard let from = source[index].mData, let to = destination[index].mData else { continue }
            let bytes = min(Int(source[index].mDataByteSize), Int(destination[index].mDataByteSize))
            memcpy(to, from, bytes)
            destination[index].mDataByteSize = UInt32(bytes)
        }
        return copy
    }
}
