# Contributing

Thanks for helping. A few rules keep Speak Away what it is:

1. **Local first.** Dictation works offline after the model download.
2. **Your data stays yours.** Meeting notes are plain Markdown files, with a JSON file beside each for the app, in `~/Library/Application Support/Speak Away/Meetings/`. No telemetry, no accounts.
3. **Tests first** for new logic and bug fixes. For the Mac app, run `cd app && swift test`. For the Python prototype, run `python3 -m unittest discover -s tests`.
4. **Return new objects** instead of mutating inputs.
5. Commit messages: `<type>: <description>` (feat, fix, refactor, docs, test, chore, perf, ci).

The app's menus and screens are in Spanish today. User-facing guides live in `docs/` and `docs/es/`.
