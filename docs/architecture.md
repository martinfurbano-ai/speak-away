# Architecture

```
app/Sources/SpeakAway/
├── Engine.swift     local speech to text with WhisperKit
├── FnListener.swift Fn key events
├── Recorder.swift   microphone capture
├── Paster.swift     clipboard and paste
├── HUD.swift        dictation indicator
├── Brain/           Apple's on-device model: optional polish, summaries, Command Mode
├── Notes/           meeting capture, detection, recording and live transcript (chunking is in app/Sources/SpeakAwayCore/Notes)
└── Store/           history, dictionary, voice shortcuts, scratchpad
```

## Principles

1. **Local dictation.** Whisper runs on the Mac and works offline after the model download. The default model downloads when you first open the app, and the other one the first time you pick it. A model downloads again only if its folder on your Mac is missing or incomplete.
2. **Local text processing.** Filler-word cleanup is rule based and on by default. Optional polish (off by default), meeting summaries and Command Mode use Apple's on-device model and need macOS 26 with Apple Intelligence.
3. **Plain files.** Meeting notes are Markdown with a JSON file beside each for the app, in `~/Library/Application Support/Speak Away/Meetings/`. Live transcripts are NDJSON; the temporary journal is deleted when the note is saved. If the note cannot be saved, or the app is interrupted, the journal stays in that folder until the next meeting replaces it. Audio is never written to storage. No database.
4. **One Whisper.** Dictation and the notetaker share the same loaded model, so memory is paid once.

## Interfaces

```swift
// Engine
func transcribe(_ audio: [Float], prompt: String = "") async throws -> String

// LocalBrain
static func polish(_ text: String, style: String, language: String?) async throws -> String
static func summarize(transcript: String, language: String?) async throws -> MeetingSummary
```

## Platform choice

**The Mac app is native Swift** (`app/`), with WhisperKit running Whisper through Core ML.

```
app/Sources/SpeakAwayCore/   FnTap (double tap), SpeechGate, rule-based text processing, note formats; no AppKit
app/Sources/SpeakAway/       menu bar, FnListener (event tap), Recorder (16 kHz), Engine (WhisperKit), Paster, HUD, Welcome
app/scripts/build-app.sh     .app + .dmg (Developer ID and notarization when configured) or TARGET=appstore .pkg (sandboxed)
app/Resources/SpeakAway.icon the app icon, an Icon Composer file (Liquid Glass on macOS 26)
```

The Python package is a prototype, not part of the Mac app. **Windows and Linux** are planned, not released.
