import AVFoundation
import Foundation
import SpeakAwayCore

/// A stop or navigation away must cancel a dictation that is still waiting for a speech model.
enum PendingSpeechSelfTest {
    @MainActor
    static func run(check: (String, Bool, String) -> Void) async {
        print("(b4) pending speech preparation cancellation fixtures")
        await cancelledKeyboardStart(intent: .finish, name: "stop", check: check)
        await cancelledKeyboardStart(intent: .cancel, name: "cancel", check: check)
        await closedNote(check: check)
    }

    @MainActor
    private static func cancelledKeyboardStart(intent: SessionDispatch.Intent, name: String,
                                              check: (String, Bool, String) -> Void) async {
        let folder = SharedContainer.directory.appendingPathComponent("PendingKeyboardSelfTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let stores = SharedStores(folder: folder)
        let speech = SuspendedTranscriber(suspendFromCall: 2)
        let controller = SessionController(files: SessionFiles(folder: folder), stores: stores, transcriber: speech,
                                           makeInput: { SilentInput() })
        defer { speech.release(); controller.endSession() }
        do {
            try stores.save(PhoneSettings(language: "en", sounds: false, haptics: false))
            await controller.startSession()
            check("\(name) fixture starts with English ready", controller.speechReady, "")
            try stores.save(PhoneSettings(language: "es", sounds: false, haptics: false))
            controller.perform(.beginDictation, field: .general)
            let waiting = await waitUntil { speech.isWaiting }
            check("\(name) fixture suspends preparation for Spanish", waiting, "")
            controller.perform(intent, field: .general)
            speech.release()
            _ = await waitUntil { controller.speechReady }
            await settle()
            check("\(name) while preparing prevents a later recording", speech.starts == 0,
                  "streams started after \(name): \(speech.starts)")
            check("\(name) while preparing does not publish a recording state", !isRecording(controller.state), "\(controller.state)")
        } catch {
            check("\(name) fixture completed", false, String(describing: error))
        }
    }

    @MainActor
    private static func closedNote(check: (String, Bool, String) -> Void) async {
        let folder = SharedContainer.directory.appendingPathComponent("PendingNoteSelfTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = PhoneStore(folder: folder)
        store.updateSettings { $0.sounds = false; $0.haptics = false }
        let speech = SuspendedTranscriber(suspendFromCall: 1)
        let controller = SessionController(files: SessionFiles(folder: folder), stores: SharedStores(folder: folder),
                                           transcriber: speech, makeInput: { SilentInput() })
        defer { speech.release(); controller.endSession() }
        let dictation = NoteDictation(session: controller, store: store)
        let note = store.newNote()
        dictation.toggle(note: note.id)
        let waiting = await waitUntil { speech.isWaiting }
        check("closing-note fixture suspends initial model preparation", waiting && dictation.phase == .starting, "")
        dictation.cancelIfListening()
        speech.release()
        _ = await waitUntil { controller.speechReady }
        await settle()
        check("closing a note while preparing prevents a later recording", speech.starts == 0,
              "streams started after navigation: \(speech.starts)")
        check("closing a note while preparing restores idle note state", dictation.phase == .idle, "\(dictation.phase)")
    }

    @MainActor
    private static func waitUntil(_ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(5)
        while !condition(), Date() < deadline { try? await Task.sleep(for: .milliseconds(10)) }
        return condition()
    }

    private static func settle() async {
        for _ in 0..<8 { await Task.yield() }
        try? await Task.sleep(for: .milliseconds(100))
    }

    private static func isRecording(_ state: SessionState) -> Bool {
        if case .recording = state { return true }
        return false
    }

    private final class SuspendedTranscriber: Transcriber {
        private let lock = NSLock()
        private let suspendFromCall: Int
        private var calls = 0
        private var started = 0
        private var released = false
        private var waiter: CheckedContinuation<Void, Never>?

        init(suspendFromCall: Int) { self.suspendFromCall = suspendFromCall }
        var starts: Int { lock.withLock { started } }
        var isWaiting: Bool { lock.withLock { waiter != nil } }

        func resolveLocales(setting: String) async -> [Locale] {
            SpeechLocale.listeningLocales(setting: setting, preferred: ["en-US"], supported: ["en-US", "es-MX"])
                .map { Locale(identifier: $0) }
        }

        func prepare(locales: [Locale], progress: @escaping @Sendable (Double) -> Void) async throws {
            let shouldWait = lock.withLock { calls += 1; return calls >= suspendFromCall && !released }
            if shouldWait {
                await withCheckedContinuation { continuation in
                    lock.withLock {
                        if released { continuation.resume() } else { waiter = continuation }
                    }
                }
            }
            progress(1)
        }

        func release() {
            let continuation = lock.withLock {
                released = true
                let pending = waiter
                waiter = nil
                return pending
            }
            continuation?.resume()
        }

        func startStream(locales: [Locale]) -> TranscriptionStream {
            lock.withLock { started += 1 }
            return EmptyStream()
        }
    }

    private final class EmptyStream: TranscriptionStream {
        func feed(_ buffer: AVAudioPCMBuffer) {}
        func finish() async throws -> SpeechCandidate { SpeechCandidate(locale: "es-MX", text: "", confidence: nil) }
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
