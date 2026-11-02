# Architecture

```
speakaway/
├── providers.py     which engine does each job (tested)
├── dictation/       hotkey, recorder, paste, HUD          ← port from whisper-flow
├── stt/             speech to text: local MLX Whisper, or cloud with the user's key
├── brain/           cleanup and summaries: none, ollama, mcp, or cloud with the user's key
├── notetaker/       meeting capture, chunking, live transcript, notes
├── mcp/             MCP server so ChatGPT, Claude and others can read notes
└── cli.py           `speakaway dictate | notes | mcp`
```

## Principles

1. **Zero keys works.** `providers.resolve()` always lands on `local` for speech and `none` for the brain when there are no keys. A key is used only when the user added it.
2. **Dictation stays local on `auto`.** Even with a key, voice is transcribed on the Mac unless the user picks a cloud engine on purpose. Keys on `auto` only power the brain.
3. **Plain files.** Notes are Markdown, live transcripts are NDJSON. No database.
4. **One Whisper.** Dictation and the notetaker share the same loaded model, so memory is paid once.

## Interfaces

```python
class SpeechToText(Protocol):
    def transcribe(self, audio: "np.ndarray", language: str | None) -> str: ...

class Brain(Protocol):
    def clean(self, text: str, language: str | None) -> str: ...
    def summarize(self, transcript: str, language: str | None) -> str: ...
```

## Platform choice

**The Mac app is native Swift** (`app/`), with WhisperKit running Whisper on the Neural Engine through Core ML. A Python `.app` with MLX was the first idea, but it is fragile to package and weighs hundreds of MB; the Swift .dmg is about 2 MB and the model downloads on first launch.

```
app/Sources/SpeakAwayCore/   FnTap (double tap), SpeechGate (silence, cleanup), Providers: tested, no AppKit
app/Sources/SpeakAway/       menu bar, FnListener (event tap), Recorder (16 kHz), Engine (WhisperKit), Paster, HUD, Welcome
app/scripts/build-app.sh     .app + .dmg (Developer ID, notarized) or TARGET=appstore .pkg (sandboxed)
app/Resources/SpeakAway.icon the app icon, an Icon Composer file (Liquid Glass on macOS 26)
```

The Python package keeps the provider rules and will host the MCP connector. **Windows and Linux** later, through `faster-whisper` behind the same interface.
