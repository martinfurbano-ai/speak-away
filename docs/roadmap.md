# Roadmap

| Version | What | Done when |
|---|---|---|
| 0.1 | **Dictation.** Port whisper-flow into `speakaway/dictation`, config file, menu bar icon | Fn twice, talk, Fn, text pasted, from `speakaway dictate` |
| 0.2 | **Brain.** Cleanup of dictation with none / Ollama / user key, keys in Keychain | Same dictation, with filler words and punctuation fixed when a brain is on |
| 0.3 | **Notetaker, local.** Mic + system audio, chunks, `live.ndjson`, Markdown note | A 30-minute call produces a note with "Me" and "Them" lines |
| 0.4 | **Summaries.** Summary template, "Copy for ChatGPT" button | Note gets Summary, Decisions, Action items, Open questions |
| 0.5 | **Connectors.** MCP server: stdio for Claude Desktop, HTTP + tunnel for ChatGPT | "Summarize my last meeting" works from both |
| 1.0 | **Real app.** Signed, notarized `.app`, onboarding for permissions and keys, landing page, public repo | Someone who never opened Terminal installs and dictates in under 3 minutes |
| Later | Windows and Linux (faster-whisper), speaker separation inside "Them", custom vocabulary | |

## Open decisions

- **License:** MIT (anyone can reuse, even in closed apps) or AGPL (forks must stay open).
- **Mac only for 1.0?** Recommended yes.
- **HUD:** keep the JARVIS-style orb from whisper-flow or go quieter.
- **Domain and landing.**
