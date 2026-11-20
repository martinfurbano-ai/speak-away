import AVFoundation
import Speech
import SpeakAwayCore

/// Apple's on-device dictation engine. Automatic mode runs English and Spanish in one analyzer.
final class AppleSpeech: Transcriber {
    func resolveLocales(setting: String) async -> [Locale] {
        let supported = await DictationTranscriber.supportedLocales.map(\.identifier)
        return SpeechLocale.listeningLocales(setting: setting, preferred: Locale.preferredLanguages,
                                             supported: supported).map { Locale(identifier: $0) }
    }

    func prepare(locales: [Locale], progress: @escaping @Sendable (Double) -> Void) async throws {
        for locale in locales {
            guard await DictationTranscriber.supportedLocale(equivalentTo: locale) != nil else {
                throw TranscriberError.unsupportedLocale(locale.identifier)
            }
        }
        let modules = locales.map(Self.makeModule)
        progress(0)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: modules) {
            let watcher = request.progress.observe(\.fractionCompleted, options: [.initial, .new]) { value, _ in
                progress(value.fractionCompleted)
            }
            defer { watcher.invalidate() }
            do { try await request.downloadAndInstall() }
            catch { throw TranscriberError.assetsUnavailable(String(describing: error)) }
        }
        guard await AssetInventory.status(forModules: modules) == .installed else {
            throw TranscriberError.assetsUnavailable("Required dictation models are not installed: \(locales.map(\.identifier))")
        }
        progress(1)
    }

    static func modelState(for locales: [Locale]) async -> SpeechModelState {
        for locale in locales {
            guard await DictationTranscriber.supportedLocale(equivalentTo: locale) != nil else { return .failed }
        }
        switch await AssetInventory.status(forModules: locales.map(Self.makeModule)) {
        case .installed: return .installed
        case .supported: return .missing
        case .downloading: return .downloading(0)
        case .unsupported: return .failed
        @unknown default: return .unknown
        }
    }

    func startStream(locales: [Locale]) -> TranscriptionStream {
        AppleSpeechStream(locales: locales)
    }

    fileprivate static func makeModule(locale: Locale) -> DictationTranscriber {
        DictationTranscriber(locale: locale, contentHints: [], transcriptionOptions: [.punctuation],
                             reportingOptions: [], attributeOptions: [.transcriptionConfidence])
    }
}

/// Both recognizers receive identical audio and finish before a complete hypothesis is chosen.
private final class AppleSpeechStream: TranscriptionStream {
    private let rawContinuation: AsyncStream<AVAudioPCMBuffer>.Continuation
    private let analyzer: SpeechAnalyzer
    private var task: Task<SpeechCandidate, Error>?

    init(locales: [Locale]) {
        let (buffers, continuation) = AsyncStream<AVAudioPCMBuffer>.makeStream()
        rawContinuation = continuation
        let modules = locales.map(AppleSpeech.makeModule)
        analyzer = SpeechAnalyzer(modules: modules,
                                  options: SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .whileInUse))
        let analyzer = self.analyzer
        task = Task {
            defer { continuation.finish() }
            return try await Self.run(analyzer: analyzer, modules: modules, locales: locales, buffers: buffers)
        }
    }

    func feed(_ buffer: AVAudioPCMBuffer) {
        guard let copy = buffer.copied() else { return }
        rawContinuation.yield(copy)
    }

    func finish() async throws -> SpeechCandidate {
        rawContinuation.finish()
        guard let task else { throw CancellationError() }
        return try await task.value
    }

    func cancel() async {
        rawContinuation.finish()
        task?.cancel()
        await analyzer.cancelAndFinishNow()
        _ = await task?.result
    }

    private static func run(analyzer: SpeechAnalyzer, modules: [DictationTranscriber], locales: [Locale],
                            buffers: AsyncStream<AVAudioPCMBuffer>) async throws -> SpeechCandidate {
        let collectors = zip(modules, locales).map { module, locale in
            Task { () throws -> SpeechCandidate in
                var pieces: [SpeechCandidate] = []
                for try await result in module.results where result.isFinal {
                    pieces.append(SpeechConfidence.candidate(text: result.text, locale: locale.identifier))
                }
                return SpeechConfidence.aggregate(pieces, locale: locale.identifier)
            }
        }
        do {
            guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: modules) else {
                throw TranscriberError.noAudioFormat
            }
            try await analyzer.prepareToAnalyze(in: format)
            let (inputs, inputContinuation) = AsyncStream<AnalyzerInput>.makeStream()
            defer { inputContinuation.finish() }
            try await analyzer.start(inputSequence: inputs)
            let converter = BufferConverter(target: format)
            for await buffer in buffers {
                try Task.checkCancellation()
                if let converted = try converter.convert(buffer) {
                    inputContinuation.yield(AnalyzerInput(buffer: converted))
                }
            }
            inputContinuation.finish()
            try Task.checkCancellation()
            try await analyzer.finalizeAndFinishThroughEndOfInput()
            var candidates: [SpeechCandidate] = []
            for collector in collectors { candidates.append(try await collector.value) }
            let preferred = locales.first?.identifier ?? SpeechLocale.fallback
            return SpeechSelection.choose(candidates, preferredLocale: preferred)
                ?? SpeechCandidate(locale: preferred, text: "", confidence: nil)
        } catch {
            collectors.forEach { $0.cancel() }
            await analyzer.cancelAndFinishNow()
            throw error
        }
    }
}

/// Converts microphone buffers to the format the speech engine asked for. The converter is kept between
/// buffers (sample-rate conversion has state) and rebuilt if the input format changes, as on a route change.
/// The meeting recorder uses it too.
final class BufferConverter {
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
