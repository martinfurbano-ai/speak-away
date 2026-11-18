# Security and privacy

- Audio is processed on your computer. Audio is never written to storage. The Mac app’s only network requests go to Hugging Face, to download the model and, when they are not cached, small tokenizer files. Hugging Face sees the requests.
- No account, no analytics, no tracking, no ads.
- History is on by default and keeps at most 2,000 entries on your Mac: final and raw dictated text, app name, date and word count. You can turn history off and delete entries one by one.
- History, dictionary, voice shortcuts, writing styles, scratchpad notes, meeting notes, the downloaded speech model and a small debug log live in `~/Library/Application Support/Speak Away`. These are plain files, not encrypted by Speak Away. Stats are plain counters; stats and settings live in the app's preferences. To delete this data, quit the app, remove that folder and run `defaults delete com.opensourceeverything.speakaway` to clear preferences.
- During a meeting, a temporary live transcript journal is kept in `~/Library/Application Support/Speak Away/Meetings/` and deleted when the note is saved. If the note cannot be saved, or the app is interrupted, the journal stays in that folder until the next meeting replaces it. The debug log keeps the last 300 lines: key events, action names, pasted character counts and errors, never what you dictated.
- Recording other people may require their consent where you live. System audio includes every sound your Mac plays except Speak Away's own, so music or video can appear in a transcript. The meeting page shows a recording indicator.

To report a vulnerability, open an issue in this repository without exploit details and ask for a private way to share them.
