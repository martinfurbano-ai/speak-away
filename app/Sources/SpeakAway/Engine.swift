import Foundation
import WhisperKit

/// Local Whisper through WhisperKit (Core ML, runs on the Neural Engine). No key, no internet after the download.
@MainActor
final class Engine: ObservableObject {
    enum State: Equatable {
        case idle
        case downloading(Double)
        case loading
        case ready
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    private var kit: WhisperKit?
    private var preparing: Task<Void, Never>?

    var isReady: Bool { state == .ready }

    func prepare() {
        preparing?.cancel()
        kit = nil
        let variant = Settings.model
        preparing = Task { await load(variant) }
    }

    private func load(_ variant: String) async {
        do {
            let folder = try await localFolder(for: variant)
            state = .loading
            let config = WhisperKitConfig(
                model: variant,
                downloadBase: Settings.modelsDirectory,
                modelFolder: folder.path,
                verbose: false,
                logLevel: .error,
                prewarm: true,
                load: true,
                download: false
            )
            let loaded = try await WhisperKit(config)
            guard !Task.isCancelled else { return }
            kit = loaded
            state = .ready
        } catch {
            if !Task.isCancelled { state = .failed(error.localizedDescription) }
        }
    }

    /// Uses the copy on disk when it is complete, so the app works offline after the first launch.
    private func localFolder(for variant: String) async throws -> URL {
        let folder = Settings.modelsDirectory
            .appendingPathComponent("models/argmaxinc/whisperkit-coreml/\(variant)", isDirectory: true)
        let needed = ["AudioEncoder.mlmodelc", "TextDecoder.mlmodelc", "MelSpectrogram.mlmodelc"]
        if needed.allSatisfy({ FileManager.default.fileExists(atPath: folder.appendingPathComponent($0).path) }) {
            return folder
        }
        state = .downloading(0)
        return try await WhisperKit.download(variant: variant, downloadBase: Settings.modelsDirectory) { progress in
            let fraction = progress.fractionCompleted
            Task { @MainActor [weak self] in
                if case .downloading = self?.state { self?.state = .downloading(fraction) }
            }
        }
    }

    func transcribe(_ audio: [Float]) async throws -> String {
        guard let kit else { return "" }
        let language = Settings.language == "auto" ? nil : Settings.language
        let options = DecodingOptions(
            task: .transcribe,
            language: language,
            temperature: 0,
            usePrefillPrompt: true,
            detectLanguage: language == nil,
            skipSpecialTokens: true,
            withoutTimestamps: true,
            chunkingStrategy: .vad
        )
        let results: [TranscriptionResult] = try await kit.transcribe(audioArray: audio, decodeOptions: options)
        return results.map(\.text).joined(separator: " ")
    }
}
