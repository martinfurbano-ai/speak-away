"""The optional brain: cleans up dictation and writes meeting summaries.

none       keep the raw text (default with no keys)
ollama     a local model, no key
mcp        nothing runs here; ChatGPT or Claude read the note through the connector
anthropic, openai, groq, openrouter   the user's own key
"""

from typing import Optional, Protocol

SUMMARY_SECTIONS = ("Summary", "Decisions", "Action items", "Open questions")


class Brain(Protocol):
    def clean(self, text: str, language: Optional[str] = None) -> str:
        """Fix punctuation and filler words. Never changes the meaning."""
        ...

    def summarize(self, transcript: str, language: Optional[str] = None) -> str:
        """Markdown with the SUMMARY_SECTIONS, in the meeting's language."""
        ...
