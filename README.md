# Speak Away

Open-source voice dictation and meeting notes that run on your own computer.

Double-tap a key, talk, and the text appears wherever your cursor is. Turn on the notetaker and every meeting becomes a clean Markdown note in a folder you own. No account, no subscription, and no API key required.

Created by **Martín Urbano** for [Open Source Everything](https://www.instagram.com/opensourceeverything/): free, open versions of the apps people pay a subscription for.

**[Download for Mac](https://github.com/martinfurbano-ai/speak-away/releases/latest/download/SpeakAway.dmg)** · [Website](https://speakaway.heliospanama.com)

> Version 0.1 ships dictation. The notetaker is next, see [docs/roadmap.md](docs/roadmap.md).

[Leer en español](README.es.md)

## What it does

| | |
|---|---|
| **Dictation** | Fn twice to start, Fn to stop. Whisper runs on your Mac, the text is pasted where you were typing. |
| **Notetaker** | Records your mic and the call audio as two tracks, transcribes live, saves a note when the meeting ends. |
| **Brain (optional)** | Cleans up dictation and writes meeting summaries. Off by default. |
| **Connectors** | ChatGPT, Claude and other MCP clients can read your notes and summarize them with your own subscription. |

## You never need an API key

Everything has a free, local path. Keys are an upgrade, never a requirement.

| Job | Without a key | With your own key |
|---|---|---|
| Speech to text | Whisper on your Mac (default) | Groq, OpenAI, ElevenLabs, Deepgram |
| Cleanup and summaries | None, Ollama (local), or ChatGPT/Claude through a connector | Anthropic, OpenAI, Groq, OpenRouter |

Keys live in the macOS Keychain, are only sent to the provider they belong to, and never touch the config file. Step by step: [docs/bring-your-own-key.md](docs/bring-your-own-key.md).

## Docs

- [Architecture](docs/architecture.md): how the pieces fit
- [Notetaker](docs/notetaker.md): how meeting notes work, from capture to summary
- [Bring your own key](docs/bring-your-own-key.md): getting a key from each provider
- [Connect ChatGPT or Claude](docs/connect-chatgpt.md): use your subscription instead of a key
- [Roadmap](docs/roadmap.md)

## Install

1. Download [SpeakAway.dmg](https://github.com/martinfurbano-ai/speak-away/releases/latest/download/SpeakAway.dmg) and drag Speak Away to Applications.
2. Open it. If macOS says it cannot verify the developer, go to System Settings › Privacy & Security and click **Open Anyway**.
3. Grant Microphone, Input Monitoring (for the Fn key) and Accessibility (to paste). The voice model (about 630 MB) downloads once.
4. If Fn opens the emoji picker: System Settings › Keyboard › "Press 🌐 key to" › Do Nothing.

Requires a Mac with Apple Silicon (M1 or newer) and macOS 14 or later.

## Develop

The Mac app is Swift + [WhisperKit](https://github.com/argmaxinc/WhisperKit) in [`app/`](app):

```sh
cd app
swift test                      # core logic
./scripts/build-app.sh          # builds app/dist/SpeakAway.dmg
./.build/arm64-apple-macosx/release/SpeakAway --transcribe audio.wav   # transcribe a file, no keyboard needed
```

The Python package (`speakaway/`) holds the provider rules and the upcoming MCP connector: `python3 -m unittest discover -s tests`.

## Credits

Made by Martín Urbano. The first dictation prototype was built with Sofía ([Sofiache26](https://github.com/Sofiache26)). Speech recognition by OpenAI Whisper through Argmax's WhisperKit.

## License

[MIT](LICENSE). Contributions welcome, see [CONTRIBUTING.md](CONTRIBUTING.md).
