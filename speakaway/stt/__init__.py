"""Speech to text. `local` (MLX Whisper) is the default and needs no key.

Cloud engines (openai, groq, elevenlabs, deepgram) only run when the user picked
one on purpose and added its key. See speakaway.providers.resolve.
"""

from typing import Optional, Protocol


class SpeechToText(Protocol):
    def transcribe(self, audio, language: Optional[str] = None) -> str:
        """audio: mono float32 at 16 kHz. Returns the text."""
        ...
