import AVFoundation
import Foundation
import SpeakAwayCore

/// A missing locale model must block dictation, including a direct request from the keyboard.
enum SpeechReadinessSelfTest {
    @MainActor
    static func run(check: (String, Bool, String) -> Void) async {
        let folder = SharedContainer.directory.appendingPathComponent("ReadinessSelfTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let stores = SharedStores(folder: folder)
        do {
            try stores.save(PhoneSettings().changing { $0.sounds = false; $0.haptics = false })
        } catch {
            check("the readiness fixture was saved", false, String(describing: error))
            return
        }
        let transcriber = MissingModelTranscriber()
        let controller = SessionController(files: SessionFiles(folder: folder), stores: stores, transcriber: transcriber,
                                           makeInput: { SilentInput() })
        defer { controller.endSession() }
        await controller.startSession()
        let deadline = Date().addingTimeInterval(5)
        while controller.problem == nil, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
        check("a missing Spanish model reports its failure", controller.problem != nil && !controller.speechReady,
              controller.lastErrorDetail ?? "")
        controller.perform(.beginDictation, field: .general)
        check("the keyboard cannot start recognition after a model failure", transcriber.starts == 0,
              "streams started: \(transcriber.starts)")
        let isRecording: Bool
        if case .recording = controller.state { isRecording = true } else { isRecording = false }
        check("a model failure cannot publish a recording state", !isRecording, "\(controller.state)")
    }

    private final class MissingModelTranscriber: Transcriber {
        private(set) var starts = 0
        func resolveLocales(setting: String) async -> [Locale] {
            [Locale(identifier: "en-US"), Locale(identifier: "es-MX")]
        }
        func prepare(locales: [Locale], progress: @escaping @Sendable (Double) -> Void) async throws {
            throw TranscriberError.assetsUnavailable("Spanish model fixture is unavailable")
        }
        func startStream(locales: [Locale]) -> TranscriptionStream {
            starts += 1
            return EmptyStream()
        }
    }

    private final class EmptyStream: TranscriptionStream {
        func feed(_ buffer: AVAudioPCMBuffer) {}
        func finish() async throws -> SpeechCandidate { SpeechCandidate(locale: "en-US", text: "", confidence: nil) }
        func cancel() async {}
    }

    private final class SilentInput: AudioInput {
        let needsMicrophone = false
        var onEvent: ((AudioInputEvent) -> Void)?
        var preferredInputUID = ""
        func start(onBuffer: @escaping (AVAudioPCMBuffer) -> Void) async throws {}
        func stop() {}
    }
}
