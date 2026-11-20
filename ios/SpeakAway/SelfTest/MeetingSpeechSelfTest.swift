import Foundation
import SpeakAwayCore

/// Feeds the same Spanish fixture used for dictation into the room-meeting speech path.
enum MeetingSpeechSelfTest {
    @MainActor
    static func run(path: String, expectedLanguage: String, check: (String, Bool, String) -> Void) async {
        let speech = MeetingSpeech()
        let locales = await speech.resolveLocales(setting: PhoneSettings().language)
        check("a default meeting prepares Spanish and English",
              Set(locales.map { SpeechLocale.languageCode($0.identifier) }) == Set(["es", "en"]), "")
        let errors = ErrorBox()
        do {
            try await speech.prepare(locales: locales) { _ in }
            let listener = speech.listen(locales: locales, onSnapshot: { _ in }, onFailure: { errors.set($0) })
            let input = FileInput(url: URL(fileURLWithPath: path), speed: 4)
            do {
                try await input.start { listener.feed($0) }
                try await input.play()
                input.stop()
                let snapshot = await listener.finish()
                if let error = errors.value { throw error }
                check("the meeting selected the spoken language",
                      snapshot.map { SpeechLocale.languageCode($0.locale) == expectedLanguage } ?? false, snapshot?.locale ?? "no result")
                if let candidate = snapshot?.candidate {
                    print("  selected meeting locale: \(candidate.locale), confidence: \(candidate.confidence.map { String($0) } ?? "unavailable")")
                }
                let text = snapshot?.candidate.text.lowercased() ?? ""
                check("the Spanish meeting transcript contains the fixture words",
                      text.contains("equipo") && text.contains("informe"), text)
            } catch {
                input.stop()
                await listener.cancel()
                throw error
            }
        } catch {
            #if targetEnvironment(simulator)
            if (error as? MeetingSpeech.Failure) == .notAvailable {
                print("  [skip] needs a real iPhone (simulator has no meeting speech engine): default Spanish meeting transcription")
                return
            }
            if (error as? TranscriberError) == .noAudioFormat {
                print("  [skip] needs a real iPhone (simulator has no speech audio format): default Spanish meeting transcription")
                return
            }
            #endif
            check("default Spanish meeting transcription completed", false, String(describing: error))
        }
    }

    private final class ErrorBox: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: Error?
        var value: Error? { lock.lock(); defer { lock.unlock() }; return stored }
        func set(_ error: Error) { lock.lock(); defer { lock.unlock() }; stored = stored ?? error }
    }
}
