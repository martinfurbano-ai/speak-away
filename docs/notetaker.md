# Notetaker

Meeting notes shipped in v0.2.0 and are transcribed on your Mac.

Full walkthrough in Spanish: [es/notetaker.md](es/notetaker.md).

1. **Start:** detects likely meetings from running apps and microphone use, and asks once ("¿Tomo notas?", Take notes?); or use the menu bar button. Zoom, Microsoft Teams, FaceTime and Webex are recognized. Slack and WhatsApp count only on macOS 14.2 or later, when macOS shows that they are using the microphone. Google Meet detection is not wired up.
2. **Capture two tracks:** your mic ("Yo") and system audio ("Ellos"). System audio includes every sound your Mac plays except Speak Away's own, so music or video can appear in the transcript. macOS 14.4+ tries Core Audio process taps, which need permission to record system audio. ScreenCaptureKit is the fallback: it is used on macOS 14.0 to 14.3, and when the tap cannot start. With ScreenCaptureKit, macOS asks for screen recording permission instead, and Speak Away uses only the sound: it discards the video frames. No virtual audio driver needed. These tracks separate microphone input from system audio, not individual speakers.
3. **Chunk:** about 20 s per chunk, preferring pauses; without a pause, a chunk is cut at 30 s.
4. **Transcribe:** the same local Whisper (WhisperKit) as dictation.
5. **Live transcript:** one JSON line per transcribed chunk in `live.ndjson` (`speaker` is `me` or `them`, `start` is seconds from the start of the meeting, and `text` is the words), shown on the meeting page. This journal does not guarantee recovery after a crash.
6. **Note:** when recording stops (you stop it, or Speak Away stops it by itself shortly after a call it detected ends), a Markdown file with frontmatter named `<date> <title>.md`, plus a `.json` beside it for the app, in `~/Library/Application Support/Speak Away/Meetings/`. The Markdown file starts with frontmatter (`title`, `app`, `date`, `duration`), then lists the transcript as `**Yo** 00:00:04 text` and `**Ellos** 00:00:09 text` lines; when you press "Resumir", the summary is appended after the transcript. These are plain files; Speak Away does not encrypt them. Audio is never written to storage. The live journal is deleted when the note is saved. If the note cannot be saved, or the app is interrupted, the journal stays in that folder until the next meeting replaces it.
7. **Summary (optional):** the note has no summary until you press "Resumir" (Summarize). Apple's on-device model needs macOS 26 with Apple Intelligence. It produces up to four sections: Resumen (summary), Decisiones (decisions), Tareas (action items), Preguntas abiertas (open questions). Empty sections are left out. "Resumir otra vez" (Summarize again) re-runs the summary. "Copiar para ChatGPT" (Copy for ChatGPT) copies the notes as a prompt you can paste into ChatGPT or Claude yourself.

Recording others may require consent. The meeting page shows an indicator while recording.
