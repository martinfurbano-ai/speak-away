# Speak Away

Open-source voice dictation and meeting notes that run on your own computer.

Free, open source dictation. Hold Fn, talk, let go, and the text appears wherever your cursor is. Turn on the notetaker to transcribe a meeting; press "Resumir" (Summarize) to request a summary. No account or subscription. Fork it and make it yours.

Created by **Martín Urbano** for [Open Source Everything](https://www.instagram.com/opensourceeverything/).

**[Download for Mac](https://github.com/martinfurbano-ai/speak-away/releases/latest/download/SpeakAway.dmg)** · [Website](https://speakaway.heliospanama.com)

> Version 0.2 ships dictation, Command Mode, meeting notes, dictionary, voice shortcuts, styles per kind of app, history and a scratchpad. What comes next: [docs/roadmap.md](docs/roadmap.md).

[Leer en español](README.es.md)

## What it does

| | |
|---|---|
| **Dictation** | Hold Fn to talk, or tap Fn twice for hands-free. Whisper runs on your Mac, the text is pasted where you were typing. |
| **Command Mode** | Select text, hold Control + Fn and say "make it shorter" or "translate to Spanish". Runs on Apple's on-device model and needs macOS 26 with Apple Intelligence. |
| **Notetaker** | Records your mic and system audio as two tracks ("Yo" and "Ellos"), no bots, and transcribes live. System audio includes every sound your Mac plays except Speak Away's own, so music or video can appear in the transcript. The note has no summary until you press "Resumir" (Summarize). |
| **Your voice** | Personal dictionary, voice shortcuts ("my address" types the whole thing), a writing style per kind of app (messages, email, work and notes, everything else), history and a scratchpad. |

## Private by design

Dictation runs on your Mac with Whisper. No account, no analytics, no tracking, no ads. The Mac app’s only network requests go to Hugging Face, to download the model and, when they are not cached, small tokenizer files. Filler-word cleanup is rule based, on by default, and needs no Apple Intelligence. Meeting summaries, optional "Pulir con Apple Intelligence" polish (off by default) and Command Mode use Apple's on-device model and need macOS 26 with Apple Intelligence. Dictation itself does not.

## Docs

- [Architecture](docs/architecture.md): how the pieces fit
- [Notetaker](docs/notetaker.md): how meeting notes work, from capture to summary
- [Bring your own key](docs/bring-your-own-key.md): planned
- [Connect ChatGPT or Claude](docs/connect-chatgpt.md): planned
- [Roadmap](docs/roadmap.md)

## Install

1. Download [SpeakAway.dmg](https://github.com/martinfurbano-ai/speak-away/releases/latest/download/SpeakAway.dmg) and drag Speak Away to Applications.
2. Open it. The download contains a signed and notarized app in a .dmg.
3. Grant Microphone, Input Monitoring (for the Fn key) and Accessibility (to paste). Meeting notes also need macOS permission to capture system audio (see [Notetaker](docs/notetaker.md)). The default model downloads when you first open the app, and the other one the first time you pick it. A model downloads again only if its folder on your Mac is missing or incomplete. The sizes are about 632 MB (precise, default) or 216 MB (fast).
4. While it runs, Speak Away sets the macOS option “Press 🌐 key to” to Do Nothing so Fn does not open the emoji picker. It puts your setting back when you quit normally; if the app closes unexpectedly, the option stays on Do Nothing and you can change it in System Settings › Keyboard.

Requires a Mac with Apple Silicon (M1 or newer) and macOS 14 or later.

With Accessibility permission, Speak Away pastes for you and about 1.5 seconds later restores what you had copied, unless you copied something else in between. Without it, the text stays on the clipboard for you to paste.

## FAQ

**What languages does it support?** English and Spanish, with automatic detection. The app's own menus and screens are in Spanish today.

## Develop

Building needs Xcode 26 or later.

The Mac app is Swift + [WhisperKit](https://github.com/argmaxinc/WhisperKit) in [`app/`](app):

```sh
cd app
swift test                      # core logic
./scripts/build-app.sh          # builds app/dist/SpeakAway.dmg
./.build/arm64-apple-macosx/release/SpeakAway --transcribe audio.wav   # transcribe a file, no keyboard needed
```

The Python package (`speakaway/`) is a prototype, not part of the Mac app: `python3 -m unittest discover -s tests`.

## Credits

Made by Martín Urbano. The first dictation prototype was built with Sofía ([Sofiache26](https://github.com/Sofiache26)). Speech recognition by OpenAI Whisper through Argmax's WhisperKit.

## License

[MIT](LICENSE). Contributions welcome, see [CONTRIBUTING.md](CONTRIBUTING.md).
