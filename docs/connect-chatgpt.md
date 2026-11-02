# Connect ChatGPT or Claude

There is no official way for another app to run on your ChatGPT subscription. So it works the other way around: **ChatGPT or Claude connect to Speak Away** through MCP and read your notes. The thinking happens in their app, on your plan.

## MCP tools

| Tool | Does |
|---|---|
| `list_notes` | Recent meetings and dictations |
| `get_note` | One full note |
| `search_notes` | Search all notes |
| `get_live_transcript` | The meeting happening right now |
| `save_summary` | Write a summary back into a note (off by default) |

## Three levels

1. **Copy for ChatGPT** (any plan, no setup): a button copies the transcript plus summary instructions. Paste into any chat.
2. **Claude Desktop** (local, stdio): add to `claude_desktop_config.json`:
   ```json
   { "mcpServers": { "speak-away": { "command": "speakaway", "args": ["mcp"] } } }
   ```
3. **ChatGPT** (paid plans with developer mode): ChatGPT only connects to remote HTTPS MCP servers. `speakaway mcp --http` serves on localhost and opens a tunnel (cloudflared or OpenAI's MCP tunnel) with a rotating access token. In ChatGPT: Settings → Apps & Connectors → Advanced → Developer mode → create a connector with the URL ending in `/mcp`. OpenAI has moved this setting during 2026 and plan availability varies; check OpenAI's docs if it is not where described.

Read-only by default. Closing the connector closes the tunnel.
