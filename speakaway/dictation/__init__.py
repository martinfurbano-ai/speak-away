"""Dictation: double-tap Fn, talk, Fn again, text is pasted at the cursor.

Port from whisper-flow/flow.py (roadmap 0.1):
- hotkey.py   Quartz event tap on the Fn flag (on_flags)
- recorder.py sounddevice input stream at 16 kHz (on_audio, start, stop)
- paste.py    clipboard + Cmd+V, restoring the previous clipboard (paste)
- hud.py      the orb overlay (Pill view, tick, build_ui)
Transcription moves out to speakaway.stt so the notetaker can share the model.
"""
