# Roadmap

Released: v0.2.1 for Mac. Rows marked planned describe future work, not features in the app today.

| Version | What | Done when |
|---|---|---|
| 0.2.1 (released) | **Paste and Fn fixes.** The Fn event tap runs on its own thread and records key-event times so a busy app does not delay Cmd+V or merge separate Fn presses | Dictations are marked as ours and transient on the clipboard; restoring it waits 1.5 seconds and never restores an earlier dictation |
| 0.2.0 (released) | **Local dictation and meeting notes.** Native Mac app in `app/` (Swift + WhisperKit), menu bar, HUD, downloadable .dmg. Hub with a Liquid Glass sidebar on macOS 26; history, scratchpad, dictionary, voice snippets, styles per kind of app, rule-based filler-word cleanup and backtracking, hold-to-talk, mic + system audio notes, sounds, mic picker. Optional polish, Command Mode and user-triggered meeting summaries use Apple's on-device model and need macOS 26 with Apple Intelligence | Press "Resumir" for up to four sections: Resumen, Decisiones, Tareas, Preguntas abiertas; empty sections are omitted. "Copiar para ChatGPT" copies a prompt for manual pasting |
| Later (planned) | **Provider options.** Ollama, user-supplied keys and Keychain storage | Not implemented in the Mac app |
| Later (planned) | **Connectors.** MCP server: stdio for Claude Desktop, HTTP + tunnel for ChatGPT | Not implemented in the Mac app |
| Later (planned) | **iPhone app and keyboard.** | Coming soon |
| Later (planned) | Windows and Linux (faster-whisper), speaker separation inside "Ellos" | Not implemented in the Mac app |
