import AVFoundation
import Foundation
import Speech
import SpeakAwayBrain
import SpeakAwayCore

/// The app checks itself when launched with `--self-test`, for a machine without a person to tap things:
///
///     xcrun simctl launch --console-pty <device> com.opensourceeverything.speakaway --self-test \
///         [--transcribe-file <audio>] [--session-file <audio>] [--command-file <audio>] [--locale <id>]
///
/// It prints what happened and exits with 0 when every check passed. Nothing here ships a feature; it only
/// proves the pieces work together on a device that cannot be driven by hand.
enum SelfTest {
    static func runIfRequested(arguments: [String] = CommandLine.arguments) {
        guard arguments.contains("--self-test") else { return }
        setvbuf(stdout, nil, _IOLBF, 0)
        Task { @MainActor in
            let passed = await Runner(arguments: arguments).run()
            print(passed ? "SELF TEST RESULT: PASS" : "SELF TEST RESULT: FAIL")
            exit(passed ? 0 : 1)
        }
    }

    /// A number written from one task and read from another.
    private final class Peak: @unchecked Sendable {
        private let lock = NSLock()
        private var stored = 0.0
        var value: Double { lock.lock(); defer { lock.unlock() }; return stored }
        func raise(to candidate: Double) { lock.lock(); stored = max(stored, candidate); lock.unlock() }
    }

    @MainActor
    private final class Runner {
        let arguments: [String]
        var failures = 0

        init(arguments: [String]) { self.arguments = arguments }

        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
            return arguments[index + 1]
        }

        func check(_ name: String, _ ok: Bool, _ detail: String = "") {
            if !ok { failures += 1 }
            print("  [\(ok ? "pass" : "FAIL")] \(name)\(detail.isEmpty ? "" : ": \(detail)")")
        }

        func run() async -> Bool {
            print("SELF TEST start (\(Date()))")
            groupContainer()
            textPipeline()
            brainStatus()
            if let path = value(after: "--transcribe-file") { await transcribeFile(path) }
            if let path = value(after: "--session-file") { await sessionDemo(path, commandPath: value(after: "--command-file") ?? path) }
            return failures == 0
        }

        // MARK: (a) shared container

        func groupContainer() {
            print("(a) shared container")
            let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SessionChannel.appGroupID)
            print("  group id: \(SessionChannel.appGroupID)")
            print("  containerURL: \(group?.path ?? "nil")")
            check("the App Group folder resolves", group != nil)
            check("SharedContainer uses it", SharedContainer.isAppGroup && SharedContainer.directory.path == group?.path,
                  SharedContainer.directory.path)

            // The app writes a file the way it writes the session state; the keyboard reads the same path.
            let probe = SharedContainer.file("selftest-probe.json")
            let payload = "written by the app at \(Date())"
            do {
                try Data(payload.utf8).write(to: probe, options: .atomic)
                let readBack = (try? String(contentsOf: SharedContainer.file("selftest-probe.json", in: SharedContainer.directory), encoding: .utf8)) ?? ""
                check("a file written by the app is read back at the keyboard's path", readBack == payload, probe.path)
            } catch {
                check("the probe file can be written", false, "\(error)")
            }

            // The real transport files, written and read through the same code the keyboard uses.
            let files = SessionFiles()
            let stamp = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970))
            files.write(state: .ready(until: nil), at: stamp)
            let roundTrip = SessionFiles().readState()
            check("the session state file round-trips in the group folder",
                  roundTrip?.state == .ready(until: nil) && roundTrip?.updatedAt == stamp)
            files.write(state: .idle, at: Date())
        }

        // MARK: (b) text path

        func textPipeline() {
            print("(b) text pipeline")
            let stores = SharedStores()
            let samples: [(String, String?, FieldContext)] = [
                ("um so let's meet tomorrow at three", "en", FieldContext(kind: .general)),
                ("um so let's meet tomorrow at three", "en", FieldContext(kind: .email)),
                ("eh bueno nos vemos mañana a las tres", "es", FieldContext(kind: .general)),
                ("hello team no wait hello everyone", "en", FieldContext(kind: .general, styleOverride: .formal)),
            ]
            for (transcript, language, field) in samples {
                let prepared = DictationFlow.prepare(transcript: transcript, language: language, field: field, dictionary: stores.dictionary(),
                                                     snippets: stores.snippets(), styles: stores.styles(), autoEdit: true)
                let shown = prepared.map { "\"\($0.text)\" (style \($0.style.rawValue))" } ?? "nil"
                print("  \(field.kind.rawValue)\(field.styleOverride.map { "+\($0.rawValue)" } ?? ""): \"\(transcript)\" -> \(shown)")
                check("produces text", prepared != nil && !(prepared?.text.isEmpty ?? true))
                let lowered = prepared?.text.lowercased() ?? ""
                check("the leading filler word is gone", !lowered.hasPrefix("um") && !lowered.hasPrefix("eh"))
            }
            check("noise gives nothing", DictationFlow.prepare(transcript: "[BLANK_AUDIO]", language: nil, field: .general,
                                                                 dictionary: stores.dictionary(), snippets: stores.snippets(),
                                                                 styles: stores.styles(), autoEdit: true) == nil)
        }

        // MARK: the on-device model, status only

        func brainStatus() {
            print("(b2) on-device model (Apple Intelligence)")
            let status = LocalBrain.availability
            print("  LocalBrain.availability: \(status) (usable: \(status.isUsable))")
        }

        // MARK: (c) AppleSpeech on a file

        func transcribeFile(_ path: String) async {
            print("(c) AppleSpeech on \(path)")
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else { return check("the audio file exists", false, path) }
            let speech = AppleSpeech()
            let setting = value(after: "--locale") ?? "auto"
            let locale = await speech.resolveLocale(setting: setting)
            let supported = await DictationTranscriber.supportedLocales
            let installed = await DictationTranscriber.installedLocales
            print("  locale setting \"\(setting)\", system languages \(Locale.preferredLanguages), resolved \(locale.identifier)")
            print("  supported locales: \(supported.count), installed before: \(installed.map(\.identifier))")
            let lastStep = Peak()
            do {
                try await speech.prepare(locale: locale) { fraction in
                    let step = (fraction * 10).rounded(.down) / 10
                    if step > lastStep.value {
                        lastStep.raise(to: step)
                        print("  asset install progress \(Int(step * 100)) %")
                    }
                }
                let installedNow = await DictationTranscriber.installedLocales.map(\.identifier)
                check("the speech model for \(locale.identifier) is installed", true, "installed now: \(installedNow)")
            } catch {
                return check("the speech model for \(locale.identifier) is installed", false, "\(error)")
            }
            do {
                let started = Date()
                let stream = speech.startStream(locale: locale)
                let input = FileInput(url: url, speed: 4)
                try await input.start { stream.feed($0) }
                try await input.play()
                input.stop()
                let raw = try await stream.finish()
                print("  transcript (\(String(format: "%.1f", Date().timeIntervalSince(started))) s): \"\(raw)\"")
                check("AppleSpeech returned text", !raw.trimmingCharacters(in: .whitespaces).isEmpty)
                let stores = SharedStores()
                let language = PhoneSettings().pipelineLanguage(resolvedLocale: locale.identifier)
                if let prepared = DictationFlow.prepare(transcript: raw, language: language, field: .general, dictionary: stores.dictionary(),
                                                        snippets: stores.snippets(), styles: stores.styles(), autoEdit: true) {
                    print("  after the text pipeline: \"\(prepared.text)\" (style \(prepared.style.rawValue))")
                }
            } catch {
                check("AppleSpeech transcribed the file", false, "\(error)")
            }
        }

        // MARK: (d) a whole session, the keyboard played by the self test

        func sessionDemo(_ path: String, commandPath: String) async {
            print("(d) session end to end on \(path) (a file plays the microphone, this process plays the keyboard)")
            guard FileManager.default.fileExists(atPath: path), FileManager.default.fileExists(atPath: commandPath) else {
                return check("the audio files exist", false, "\(path) / \(commandPath)")
            }
            let folder = SharedContainer.directory.appendingPathComponent("SelfTest", isDirectory: true)
            try? FileManager.default.removeItem(at: folder)
            defer { try? FileManager.default.removeItem(at: folder) }
            let files = SessionFiles(folder: folder)
            let stores = SharedStores(folder: folder)
            let dictationAudio = FileInput(url: URL(fileURLWithPath: path), speed: 1)
            // The stand-in brain proves the plumbing of Command Mode; the real model needs Apple Intelligence.
            let brain = OnDeviceBrain(availability: { .available }, polish: { text, _, _ in text },
                                      command: { instruction, text, _ in "[\(instruction)] applied to: \(text)" })
            let controller = SessionController(files: files, stores: stores, brain: brain, makeInput: { dictationAudio })
            let keyboard = SessionClient(files: files)
            try? stores.save(PhoneSettings().changing { $0.language = value(after: "--locale") ?? "auto" })

            let loopsBack = await darwinLoopsBack()
            await controller.startSession()
            check("the session starts and publishes ready", await waitFor { keyboard.state.canRecord }, "\(keyboard.state)")
            check("the keyboard sees a live session", keyboard.isLive)
            let modelReady = await waitFor(timeout: 180) { controller.speechReady || controller.problem != nil }
            check("the speech model is ready for the session", modelReady && controller.speechReady,
                  controller.lastErrorDetail ?? "")
            guard controller.speechReady else {
                controller.endSession()
                return
            }

            // Dictation: start, the file plays, stop.
            send(keyboard, controller, .start, loopsBack: loopsBack)
            let recording = await waitFor(timeout: 5) { if case .recording = keyboard.state { return true } else { return false } }
            check("the app records after the keyboard's start", recording, "\(keyboard.state)")
            let peak = Peak()
            await withTaskGroup(of: Void.self) { group in
                group.addTask { _ = try? await dictationAudio.play() }
                group.addTask {
                    while !Task.isCancelled {
                        peak.raise(to: await MainActor.run { keyboard.state.level })
                        try? await Task.sleep(for: .milliseconds(100))
                    }
                }
                _ = await group.next()      // the file finished
                group.cancelAll()
            }
            print("  highest level published while recording: \(String(format: "%.2f", peak.value))")
            check("the level bars got a signal while the file played", peak.value > 0)
            send(keyboard, controller, .stop, loopsBack: loopsBack)
            let finished = await waitFor(timeout: 90) { self.pending(files) != nil }
            check("the app transcribes after the keyboard's stop", finished, "\(keyboard.state)")
            if let result = keyboard.takePendingResult() {
                print("  result for the keyboard: \"\(result.text)\" (command: \(result.command))")
                check("the result is plain text for insertion", !result.text.isEmpty && !result.command)
                check("the result is delivered once", keyboard.takePendingResult() == nil)
                check("it was added to the history and the stats", stores.history().first?.text == result.text && stores.stats().totalWords > 0,
                      "history \(stores.history().count) item(s)")
            } else {
                check("a result came back", false, controller.lastErrorDetail ?? "\(keyboard.state)")
            }

            // Command Mode, spoken: the second file is the instruction, applied to text the keyboard picked.
            let target = "The meeting is at three."
            send(keyboard, controller, .startCommand(on: target), loopsBack: loopsBack)
            let commandRecording = await waitFor(timeout: 5) { if case .recording = keyboard.state { return true } else { return false } }
            check("a spoken command starts recording", commandRecording, "\(keyboard.state)")
            _ = try? await dictationAudio.play(URL(fileURLWithPath: commandPath))
            send(keyboard, controller, .stop, loopsBack: loopsBack)
            _ = await waitFor(timeout: 90) { self.pending(files) != nil }
            if let result = keyboard.takePendingResult() {
                print("  command result for the keyboard: \"\(result.text)\" (command: \(result.command))")
                check("Command Mode returns the spoken instruction applied to the keyboard's text",
                      result.command && result.text.hasSuffix("applied to: \(target)"))
            } else {
                check("Command Mode produced a result", false, controller.lastErrorDetail ?? "\(keyboard.state)")
            }

            // A written command goes straight through, with no recording.
            send(keyboard, controller, .command(instruction: "make it formal", on: target), loopsBack: loopsBack)
            _ = await waitFor(timeout: 10) { self.pending(files) != nil }
            if let result = keyboard.takePendingResult() {
                check("a written command is applied without recording", result.command && result.text == "[make it formal] applied to: \(target)",
                      result.text)
            } else {
                check("a written command produced a result", false, "\(keyboard.state)")
            }

            controller.endSession()
            check("ending the session publishes idle", keyboard.state == .idle)
        }

        /// What the keyboard would insert next, without taking it.
        private func pending(_ files: SessionFiles) -> PendingResult? {
            files.inbox().pending(in: files.readState(), at: Date())
        }

        /// Sends a request the way the keyboard does: the file, then the Darwin notification. When the notification
        /// cannot loop back into this one process (checked once, up front), the controller is handed the same
        /// request directly, and the run says so.
        private func send(_ keyboard: SessionClient, _ controller: SessionController, _ message: SessionMessage, loopsBack: Bool) {
            let before = controller.state
            keyboard.send(message, field: FieldContext(kind: .general))
            if !loopsBack {
                controller.perform(SessionDispatch.intent(for: message, in: before), field: FieldContext(kind: .general))
            }
        }

        /// Whether a Darwin notification posted by this process reaches an observer in the same process.
        private func darwinLoopsBack() async -> Bool {
            let flag = Peak()
            let observer = DarwinObserver(name: SessionChannel.requestNotification) { flag.raise(to: 1) }
            DarwinNotifier.post(SessionChannel.requestNotification)
            let got = await waitFor(timeout: 2) { flag.value > 0 }
            observer.stop()
            print("  Darwin notification posted and observed inside this process: \(got ? "yes" : "no (requests are handed to the controller directly)")")
            return got
        }

        /// Polls on the main actor until `condition` holds (the session lives there) or the time is up.
        private func waitFor(timeout: TimeInterval = 20, _ condition: () -> Bool) async -> Bool {
            let end = Date().addingTimeInterval(timeout)
            while Date() < end {
                if condition() { return true }
                try? await Task.sleep(for: .milliseconds(50))
            }
            return condition()
        }
    }
}
