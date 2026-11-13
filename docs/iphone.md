# Speak Away for iPhone

Goal: everything the Mac app does, on iPhone, on the device. No account, no key, no server. Text that is dictated never leaves the phone.

Branch `iphone`. Minimum iOS 26 (SpeechAnalyzer, Foundation Models, Liquid Glass).

## How it works (like Wispr Flow on iPhone)

1. The **Speak Away keyboard** shows a big mic in any app. Tapping it the first time opens the Speak Away app, which starts a **session**: the mic stays ready in the background (orange dot) for the session length the user picked (5 min, 15 min, 1 h, until stopped). The app shows "Swipe back to keep typing" and the user returns with the system back link at the top left.
2. While a session is on, tapping the mic in the keyboard records right there. Tapping again (or the Done check) stops; the app transcribes with Apple's on-device speech, runs the same text pipeline as the Mac (dictionary, auto-edits, backtracking, snippets, style), optionally polishes with Apple's on-device model, and the keyboard inserts the result with `textDocumentProxy.insertText`.
3. Audio outside a dictation is never kept: the engine only feeds buffers to the transcriber between start and stop.

Keyboard and app talk through the App Group `group.com.opensourceeverything.speakaway`: small JSON files in the shared container plus Darwin notifications (`CFNotificationCenterGetDarwinNotifyCenter`) to wake the other side.

## Parity with the Mac app

| Mac | iPhone |
|---|---|
| Fn to dictate, pill, HUD | Keyboard mic, level bars (`BubbleMotion`), haptics and sounds |
| Hold-to-talk | Press and hold the mic: release stops |
| Command Mode on the selection | Wand key: speaks an instruction; works on `selectedText`, or on the sentence before the cursor when nothing is selected; result replaces it |
| Styles per app | Styles per kind of field: email fields (`keyboardType`/`textContentType`) use the email style, everything else messages; a style chip in the keyboard overrides it |
| History, scratchpad, dictionary, voice snippets, auto-edits, backtracking | Same core code, data in the App Group container |
| Meeting notes (mic + system audio) | Meeting notes from the mic only (iOS does not give other apps' audio): record in the app, live transcript, chunks, summary with the on-device model |
| Stats and streak | Same `UsageStats` |
| Brain (Foundation Models) | Same prompts (`BrainPrompts`), same `LocalBrain`, shared target |
| Undo | Undo key removes the last insertion |

## Layout

- `app/Sources/SpeakAwayCore`: pure logic, shared. Must compile for iOS (Foundation only). New pure pieces live here with tests:
  - `Session/SessionMessages.swift`: Codable messages keyboard to app (`start`, `stop`, `cancel`, `command(instruction, on: text)`), app state (`idle`, `ready(until:)`, `recording(level)`, `transcribing`, `done(id, text)`, `failed(reason)`), file names, notification names.
  - `Session/SessionPolicy.swift`: session lengths and when a session expires.
  - `Session/FieldKind.swift`: maps keyboard type and text content type (raw values) to `AppCategory`.
  - `Session/CommandTarget.swift`: what Command Mode rewrites (selection or the last sentence before the cursor) and how many characters to delete before inserting.
- `app/Sources/SpeakAwayBrain`: `LocalBrain` moved out of the Mac target so both apps use it (Foundation Models, guarded with `#available`). The Mac target depends on it.
- `ios/`: XcodeGen `project.yml` (generated `.xcodeproj` is ignored). The iOS project compiles `SpeakAwayCore` and `SpeakAwayBrain` straight from `../app/Sources` as framework targets, so it never resolves WhisperKit.
  - `SpeakAway` app, bundle `com.opensourceeverything.speakaway` (same as the Mac app: one App Store listing, universal purchase).
  - `SpeakAwayKeyboard` keyboard extension, bundle `com.opensourceeverything.speakaway.keyboard`, `RequestsOpenAccess` true.
  - App: `UIBackgroundModes` audio, mic and speech usage strings, URL scheme `speakaway`.

## Speech

`Transcriber` protocol with one implementation, `AppleSpeech`: `SpeechAnalyzer` + `DictationTranscriber` for dictation (punctuation on), `SpeechTranscriber` for meetings. Locale from settings (English or Spanish to start, the system language by default). Missing locale models are installed with `AssetInventory` during onboarding, with progress. WhisperKit can come later behind the same protocol.

## Meeting notes

Notes, Meetings, Record meeting. `MeetingRecorder` is the only owner of the microphone while a meeting runs: starting one ends a keyboard session, a dictation cannot start until it ends (`MicArbiter` in Core), and the keyboard says "Recording a meeting" from the shared state file. The screen can be locked while it records (`UIBackgroundModes` audio).

- One microphone hears the whole room, so the notes are paragraphs with their time (`.room`), not "Me" and "Them". A pause, a phone call or a change of microphone (AirPods) is a note inside the transcript (`.marker`), and the meeting carries on by itself when the system gives the microphone back.
- `SpeechTranscriber` with volatile results feeds the live view (the guess in a lighter color). Each settled phrase is appended to `Meetings/live.ndjson` in the App Group folder (`MeetingJournal`). If the app is killed or the phone restarts, the next launch turns the journal into a note.
- Audio is never stored: buffers go from the microphone to the transcriber and nowhere else. The recording screen says so and asks the person to let the others know they are being recorded.
- Stopping saves the note (`.md` and `.json`, the Mac format), then writes the summary, decisions, tasks and open questions with the on-device model when Brain is on and Apple Intelligence is available (`SummaryPlan`). Otherwise the transcript stays and the note says what the summary needs.
- Preview: `--preview meeting-recording` (a made-up meeting, nothing is recorded).

## App screens

Bottom tab bar (Liquid Glass): **Home** (start or stop session, streak, words, time saved, last dictations), **Notes** (meetings and scratchpad), **Library** (dictionary, voice snippets, styles), **Settings** (language, session length, brain on/off, auto-edits, sounds, haptics, keyboard setup, privacy, "Hecho por Martín Urbano para Open Source Everything"). Onboarding: mic and speech permission, add the keyboard and allow Full Access (with a button to Settings), a first test dictation inside the app.

Look: black and white, Liquid Glass, the red bubble icon from `app/Resources/SpeakAway.icon`, system fonts. The keyboard follows light and dark mode and matches the system keyboard height.

Preview mode for screenshots: launch argument `--preview <screen>` (`home`, `notes`, `library`, `settings`, `onboarding`, `keyboard`, `keyboard-recording`) shows a screen with sample data; `keyboard` renders the keyboard view inside the app.

## Checks

- `cd app && swift test` passes (all old tests plus the new ones), and `swift build` of the Mac app still passes.
- `xcodebuild` builds app and keyboard for the iOS Simulator.
- Screenshots of every screen in light and dark from the simulator.
- On a real iPhone through TestFlight: dictate into Notes and WhatsApp, Command Mode on a selection, a 5-minute meeting note.

## Release

TestFlight first, in the same App Store Connect app as the Mac (6829756587), iOS version 0.3.0. Bundle ids, the App Group and profiles are created with the scripts in the private folder, never in this repo.
