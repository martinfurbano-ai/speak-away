import AVFoundation
import Foundation
import SpeakAwayCore

/// Deterministic integration fixture, not an Apple recognition-quality test.
/// Proves that the default Spanish winner reaches the app pipeline and the keyboard's shared result.
enum BilingualSessionSelfTest {
    @MainActor
    static func run(check: (String, Bool, String) -> Void) async {
        print("(b3) default Spanish session fixture (injected recognizer candidates)")
        let folder = SharedContainer.directory.appendingPathComponent("BilingualSelfTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let stores = SharedStores(folder: folder)
        let files = SessionFiles(folder: folder)
        do {
            try stores.save(PhoneSettings().changing { $0.sounds = false; $0.haptics = false })
        } catch {
            check("the bilingual fixture was saved", false, String(describing: error))
            return
        }
        let transcriber = CandidateTranscriber()
        let input = FixtureInput()
        let controller = SessionController(files: files, stores: stores, transcriber: transcriber, makeInput: { input })
        defer { controller.endSession() }
        let keyboard = SessionClient(files: files)
        await controller.startSession()
        let readyLimit = Date().addingTimeInterval(5)
        while !controller.speechReady, controller.problem == nil, Date() < readyLimit {
            try? await Task.sleep(for: .milliseconds(20))
        }
        check("the default fixture prepares Spanish and English",
              stores.settings().language == "auto" && Set(transcriber.prepared) == Set(["en", "es"]), "")
        controller.perform(.beginDictation, field: .general)
        check("the fixture sends non-silent audio through the capture gate", input.emit(), "")
        controller.perform(.finish, field: .general)
        let resultLimit = Date().addingTimeInterval(5)
        while files.inbox().pending(in: files.readState(), at: Date()) == nil, Date() < resultLimit {
            try? await Task.sleep(for: .milliseconds(20))
        }
        let result = keyboard.takePendingResult()
        let text = result?.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // Spanish removes "eh" and keeps English "um". English or a nil language fails this assertion.
        check("the Spanish winner uses Spanish text rules before keyboard delivery",
              text == "hola equipo um revisemos el informe", result?.text ?? "no keyboard result")
        check("the keyboard receives the fixture once", result != nil && keyboard.takePendingResult() == nil, "")
        check("the default Spanish fixture is recorded in history",
              result != nil && stores.history().first?.text == result?.text, "")
    }

    private final class CandidateTranscriber: Transcriber {
        private(set) var prepared: [String] = []
        func resolveLocales(setting: String) async -> [Locale] {
            SpeechLocale.listeningLocales(setting: setting, preferred: ["en-US"], supported: ["en-US", "es-MX"])
                .map { Locale(identifier: $0) }
        }
        func prepare(locales: [Locale], progress: @escaping @Sendable (Double) -> Void) async throws {
            prepared = locales.map { SpeechLocale.languageCode($0.identifier) }
            progress(1)
        }
        func startStream(locales: [Locale]) -> TranscriptionStream { CandidateStream() }
    }

    private final class CandidateStream: TranscriptionStream {
        func feed(_ buffer: AVAudioPCMBuffer) {}
        func finish() async throws -> SpeechCandidate {
            let candidates = [
                SpeechCandidate(locale: "en-US", text: "a wrong English interpretation", confidence: 0.2),
                SpeechCandidate(locale: "es-MX", text: "eh hola equipo um revisemos el informe", confidence: 0.95),
            ]
            return SpeechSelection.choose(candidates, preferredLocale: "en-US")!
        }
        func cancel() async {}
    }

    private final class FixtureInput: AudioInput {
        let needsMicrophone = false
        var onEvent: ((AudioInputEvent) -> Void)?
        var preferredInputUID = ""
        private var sink: ((AVAudioPCMBuffer) -> Void)?
        func start(onBuffer: @escaping (AVAudioPCMBuffer) -> Void) async throws { sink = onBuffer }
        func stop() { sink = nil }
        func emit() -> Bool {
            guard let format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1),
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16_000),
                  let samples = buffer.floatChannelData?[0], let sink else { return false }
            buffer.frameLength = 16_000
            samples.update(repeating: 0.2, count: Int(buffer.frameLength))
            sink(buffer)
            return true
        }
    }
}
