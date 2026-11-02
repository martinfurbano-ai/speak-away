# Bring your own key

Speak Away never needs a key. A key makes summaries and cleanup automatic, or lets older Macs transcribe in the cloud. You pay the provider directly; Speak Away never sees your bill.

A ChatGPT Plus subscription does not include API access. To use your subscription instead, see [connect-chatgpt.md](connect-chatgpt.md).

| Provider | Where | Key starts with | Good for |
|---|---|---|---|
| Groq | [console.groq.com](https://console.groq.com) → API Keys | `gsk_` | Free tier, transcription and summaries |
| OpenAI | [platform.openai.com](https://platform.openai.com) → Billing, then API keys | `sk-` | Transcription and summaries |
| Anthropic | [console.anthropic.com](https://console.anthropic.com) → Billing, then API Keys | `sk-ant-` | Best summaries |
| OpenRouter | [openrouter.ai](https://openrouter.ai) → Credits, then Keys | `sk-or-` | One key, many models |
| ElevenLabs | [elevenlabs.io](https://elevenlabs.io) → Developers → API Keys | | Transcription |
| Ollama | [ollama.com](https://ollama.com), then `ollama pull llama3.2` | none | Fully local summaries |

In Speak Away: **Settings → Keys**, pick the provider, paste, **Test**. Keys are stored in the macOS Keychain.

Step-by-step guide in Spanish: [es/llaves-api.md](es/llaves-api.md).
