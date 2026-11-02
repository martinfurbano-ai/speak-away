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

**v1: Python + PyObjC, Mac only.** The dictation core already works this way in whisper-flow, and MLX Whisper is the fastest local option on Apple Silicon. Shipped as a signed, notarized `.app` (py2app or Briefcase) so permissions belong to "Speak Away" and not to Terminal.

**Later: Windows and Linux** through `faster-whisper` behind the same `SpeechToText` interface. A Tauri shell is the option if the UI outgrows PyObjC.
