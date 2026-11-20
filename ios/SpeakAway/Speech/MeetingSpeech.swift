import AVFoundation
import Speech
import SpeakAwayCore

/// On-device room transcription. Automatic mode gives Spanish and English modules the same audio.
final class MeetingSpeech {
    enum Failure: Error, Equatable {
        case notAvailable
    }

    func resolveLocales(setting: String) async -> [Locale] {
        let supported = await SpeechTranscriber.supportedLocales.map(\.identifier)
        return SpeechLocale.listeningLocales(setting: setting, preferred: Locale.preferredLanguages, supported: supported)
            .map { Locale(identifier: $0) }
    }

    /// All required models are installed together. Missing Spanish support is a visible preparation failure.
    func prepare(locales: [Locale], progress: @escaping @Sendable (Double) -> Void) async throws {
        guard SpeechTranscriber.isAvailable else { throw Failure.notAvailable }
        guard !locales.isEmpty else { throw TranscriberError.unsupportedLocale(SpeechLocale.fallback) }
        for locale in locales {
            guard await SpeechTranscriber.supportedLocale(equivalentTo: locale) != nil else {
                throw TranscriberError.unsupportedLocale(locale.identifier)
            }
        }
        let modules = locales.map(Self.makeModule)
        progress(0)
        do {
            switch await AssetInventory.status(forModules: modules) {
            case .unsupported:
                throw TranscriberError.unsupportedLocale(locales.map(\.identifier).joined(separator: ", "))
            case .installed:
                break
            case .supported, .downloading:
                if let request = try await AssetInventory.assetInstallationRequest(supporting: modules) {
                    let watcher = request.progress.observe(\.fractionCompleted, options: [.initial, .new]) { value, _ in
                        progress(value.fractionCompleted)
                    }
                    defer { watcher.invalidate() }
                    try await request.downloadAndInstall()
                }
            @unknown default:
                throw TranscriberError.assetsUnavailable("Unknown meeting speech asset status")
            }
            guard await AssetInventory.status(forModules: modules) == .installed else {
                throw TranscriberError.assetsUnavailable("Required meeting speech models are not installed")
            }
            for locale in locales { try await AssetInventory.reserve(locale: locale) }
            progress(1)
        } catch let error as TranscriberError {
            throw error
        } catch {
            throw TranscriberError.assetsUnavailable(String(describing: error))
        }
    }

    func listen(locales: [Locale], onSnapshot: @escaping MeetingListener.SnapshotHandler,
                onFailure: @escaping @Sendable (Error) -> Void) -> MeetingListener {
        MeetingListener(locales: locales, transcribers: locales.map(Self.makeModule),
                        onSnapshot: onSnapshot, onFailure: onFailure)
    }

    private static func makeModule(locale: Locale) -> SpeechTranscriber {
        SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [.volatileResults],
                          attributeOptions: [.audioTimeRange, .transcriptionConfidence])
    }
}
