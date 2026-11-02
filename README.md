# Speak Away

Open-source voice dictation and meeting notes that run on your own computer.

Double-tap a key, talk, and the text appears wherever your cursor is. Turn on the notetaker and every meeting becomes a clean Markdown note in a folder you own. No account, no subscription, and no API key required.

> Status: skeleton. The working dictation core comes from [whisper-flow](https://github.com/Sofiache26/whisper-flow) by Sofiache26 and is being moved in here. Nothing is installable yet. See [docs/roadmap.md](docs/roadmap.md).

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

## Requirements (first release)

Mac with Apple Silicon (M1 or newer), macOS 13.5 or later. Windows and Linux are on the roadmap through faster-whisper.

## Develop

```sh
python3 -m unittest discover -s tests
```

## License

[MIT](LICENSE). Contributions welcome, see [CONTRIBUTING.md](CONTRIBUTING.md).
