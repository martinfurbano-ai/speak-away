# Notetaker

**Rule:** it must work exactly like Wispr Flow's notetaker. Below is how we do it locally, with no API key.

Full walkthrough in Spanish: [es/notetaker.md](es/notetaker.md).

1. **Start:** auto-detects when Zoom, Meet, Teams, FaceTime or WhatsApp holds the mic and asks once; or a menu bar button; or a hotkey.
2. **Capture two tracks:** your mic ("me") and the call audio ("them"). macOS 14.4+ uses Core Audio process taps; macOS 13 uses ScreenCaptureKit audio. No virtual audio driver needed. Two tracks give speaker separation for free.
3. **Chunk:** about 20 s per chunk, cut at silences.
4. **Transcribe:** the same local Whisper (WhisperKit) as dictation.
5. **Live transcript:** one JSON line per phrase in `live.ndjson`, so a crash loses nothing.
6. **Note:** on hang-up, a Markdown file with frontmatter in `~/Documents/Speak Away/Notes/`. Audio is deleted once transcribed by default.
7. **Summary (optional):** none ("Copy for ChatGPT" button), Ollama, the user's own key, or ChatGPT/Claude via the MCP connector. Sections: Summary, Decisions, Action items (who, what, when), Open questions.

Recording others may require consent. A visible indicator is always on while recording.
