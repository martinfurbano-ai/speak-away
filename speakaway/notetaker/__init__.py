"""Meeting notetaker (roadmap 0.3). Design: docs/notetaker.md

detect.py    which meeting app holds the mic (Zoom, Meet, Teams, FaceTime, WhatsApp)
capture.py   two tracks: mic ("me") and system audio ("them")
             macOS 14.4+: Core Audio process tap; macOS 13: ScreenCaptureKit audio
chunker.py   ~20 s chunks cut at silences
live.py      appends {"t", "who", "text"} lines to live.ndjson
note.py      writes the Markdown note with frontmatter when the meeting ends
"""
