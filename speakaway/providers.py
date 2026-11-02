"""Which engine does each job, given the user's settings and the API keys they added.

Two jobs:
- stt: turns speech into text. "local" (Whisper on your Mac) always works, with no key.
- brain: cleans up dictation and writes meeting summaries. "none" keeps the raw text,
  "ollama" runs a local model, "mcp" lets ChatGPT or Claude do it from their own app,
  and the rest use the user's own API key.

Rule: Speak Away never needs a key. A key is only used when the user added it.
"""

from typing import Mapping

STT_LOCAL = "local"
STT_CLOUD = ("openai", "groq", "elevenlabs", "deepgram")

BRAIN_KEYLESS = ("none", "ollama", "mcp")
BRAIN_CLOUD = ("anthropic", "openai", "groq", "openrouter")  # order used by "auto"


def _stt(choice: str, keys: frozenset) -> str:
    if choice in STT_CLOUD and choice in keys:
        return choice
    return STT_LOCAL


def _brain(choice: str, keys: frozenset) -> str:
    if choice in BRAIN_KEYLESS:
        return choice
    if choice in BRAIN_CLOUD and choice in keys:
        return choice
    if choice == "auto":
        return next((name for name in BRAIN_CLOUD if name in keys), "none")
    return "none"


def resolve(settings: Mapping[str, str], keys) -> dict:
    """Return a new {"stt", "brain"} choice. Never changes `settings`."""
    owned = frozenset(keys)
    return {
        "stt": _stt(settings.get("stt", "auto"), owned),
        "brain": _brain(settings.get("brain", "auto"), owned),
    }
