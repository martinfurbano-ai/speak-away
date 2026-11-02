# Contributing

Thanks for helping. A few rules keep Speak Away what it is:

1. **Local first.** Every feature must work with no API key and no internet. Cloud providers are optional add-ons.
2. **Your data stays yours.** Notes are plain Markdown files in a folder the user picks. No telemetry, no accounts.
3. **Keys go in the Keychain.** Never in config files, logs or crash reports.
4. **Tests first** for new logic and bug fixes. Run `python3 -m unittest discover -s tests`.
5. **Return new objects** instead of mutating inputs.
6. Commit messages: `<type>: <description>` (feat, fix, refactor, docs, test, chore, perf, ci).

Spanish and English are both first-class. User-facing guides live in `docs/` and `docs/es/`.
