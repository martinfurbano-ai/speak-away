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

`Transcriber` has one implementation, `AppleSpeech`: `SpeechAnalyzer` + `DictationTranscriber` for dictation (punctuation on), and `SpeechTranscriber` for meetings. Unlike the Mac's multilingual Whisper model, each Apple transcriber has a fixed locale.

The default language is **Automatic (Spanish and English)**. When the phone's first supported language is Spanish or English, both Apple locale models receive the same microphone buffers. A pure Core function compares the candidates using Apple's per-run transcription confidence, weighted by the number of characters. Empty candidates lose, and a tie uses the phone's resolved locale consistently. The selected language also controls text cleanup. Explicit **Español** and **English** settings use a single locale. A phone whose first supported language is something else keeps its existing single-language system behavior.

On an English-language iPhone, leave the default language selected, finish the speech-model download in onboarding, then speak Spanish or English in the app or keyboard. No language switch is needed. Meetings use the same automatic choice. Both dictation models install during onboarding or the first dictation session; both meeting models install before the first meeting, with progress. An unavailable or failed Spanish model reports a visible error instead of quietly listening only in English.

If you change the explicit language during a live session, let the new model finish preparing and tap the mic again. A released mic gesture or a closed note never starts recording later when a download finishes.

Recognition and language selection run on the iPhone. The only downloads are Apple's speech models through `AssetInventory`; there is no third-party model, account, API key or transcription request to a server. Automatic choice selects a language for an utterance or meeting; recognition quality, accented short phrases and mixed-language speech need validation on a real iPhone.

## Meeting notes

Notes, Meetings, Record meeting. `MeetingRecorder` is the only owner of the microphone while a meeting runs: starting one ends a keyboard session, a dictation cannot start until it ends (`MicArbiter` in Core), and the keyboard says "Recording a meeting" from the shared state file. The screen can be locked while it records (`UIBackgroundModes` audio).

- One microphone hears the whole room, so the notes are paragraphs with their time (`.room`), not "Me" and "Them". A pause, a phone call or a change of microphone (AirPods) is a note inside the transcript (`.marker`), and the meeting carries on by itself when the system gives the microphone back.
- `SpeechTranscriber` with volatile results feeds the live view (the guess in a lighter color). The selected language's complete settled transcript is checkpointed to `Meetings/live.ndjson` in the App Group folder (`MeetingJournal`), keeping a change of language winner from mixing two recognizers' words. If the app is killed or the phone restarts, the next launch turns the journal into a note.
- Audio is never stored: buffers go from the microphone to the transcriber and nowhere else. The recording screen says so and asks the person to let the others know they are being recorded.
- Stopping saves the note (`.md` and `.json`, the Mac format), then writes the summary, decisions, tasks and open questions with the on-device model when Brain is on and Apple Intelligence is available (`SummaryPlan`). Otherwise the transcript stays and the note says what the summary needs.
- Preview: `--preview meeting-recording` (a made-up meeting, nothing is recorded).

## Transcript privacy

Starting with 0.3.1, **Settings > Privacy > Keep transcripts** is off by default, including when upgrading from settings saved without that key. Dictation history and meeting notes expire 240 hours after their date. The app checks at launch, on returning to the foreground, and after dictation sessions and meetings. The app also writes the history of keyboard dictations, so the same checks cover that flow. Deletion is performed at those checkpoints, so iOS does not need to wake a closed app at the exact expiry time.

The purge removes the transcript, summary and any associated journal, audio or chunk files from the shared folder. The current iPhone recorder does not persist audio. Turning **Keep transcripts** on prevents further age-based deletion; turning it off immediately removes expired items. Deleted notes cannot be restored by turning it back on.

Usage totals and streaks, dictionary, snippets, styles, settings and the notes pad are retained. The notes pad can contain text inserted by dictation, but it is a separate editable document and is not purged. History and meeting notes show a short reminder while automatic deletion is enabled.

## App screens

Bottom tab bar (Liquid Glass): **Home** (start or stop session, streak, words, time saved, last dictations), **Notes** (meetings and scratchpad), **Library** (dictionary, voice snippets, styles), **Settings** (language, session length, brain on/off, auto-edits, sounds, haptics, keyboard setup, privacy, "Hecho por Martín Urbano para Open Source Everything"). Onboarding: mic and speech permission, add the keyboard and allow Full Access (with a button to Settings), a first test dictation inside the app.

Look: black and white, Liquid Glass, the red bubble icon from `app/Resources/SpeakAway.icon`, system fonts. The keyboard follows light and dark mode and matches the system keyboard height.

Preview mode for screenshots: launch argument `--preview <screen>` (`home`, `history`, `notes`, `meetings`, `voice`, `settings`, `settings-privacy`, `onboarding-1` through `onboarding-5`, `keyboard`, `keyboard-recording`) shows a screen with sample data; `keyboard` renders the keyboard view inside the app.

## Checks

- `ios/scripts/test-core.sh` runs every Core test in an isolated Swift package without resolving WhisperKit. If necessary, set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- `.github/workflows/iphone.yml` builds the app and keyboard, runs Core tests and the iOS self-test, and captures simulator screenshots. It accepts manual runs and pushes to `codex/es-y-borrado`.
- Settings and its privacy section are captured in English and Spanish, light and dark. `settings-privacy` scrolls the real Settings list to the retention toggle.
- The iOS self-test always checks default Spanish selection, Spanish-only text rules and shared keyboard delivery with injected recognizer candidates. Separate recognition checks feed English and Spanish audio using the default setting on an English-language simulator, including keyboard delivery and the Spanish meeting path. It also deletes expired history and meeting artifacts in an isolated shared folder and verifies that statistics stay unchanged. A simulator without an Apple speech audio format or meeting engine reports an explicit skip for actual recognition, never a successful transcription claim.
- Before release, use a real iPhone to verify offline Spanish and English dictation into Notes and WhatsApp, short phrases, Command Mode, and a five-minute meeting, including model installation and device memory use. Simulator tests do not establish recognition quality.

## Release

TestFlight first, in the same App Store Connect app as the Mac (6829756587), iOS version 0.3.1. The archive script supplies the build number. This branch does not upload an archive or change App Store Connect. Bundle ids, the App Group and profiles are created with the scripts in the private folder, never in this repo.
