# Connect ChatGPT or Claude

**Planned. None of this is in the Speak Away app today.**

This design proposes that **ChatGPT or Claude connect to Speak Away** through MCP and read your notes. The tools and commands below are proposed interfaces, not working setup instructions.

## MCP tools

| Proposed tool | Intended use |
|---|---|
| `list_notes` | Recent meetings and dictations |
| `get_note` | One full note |
| `search_notes` | Search all notes |
| `get_live_transcript` | The meeting happening right now |
| `save_summary` | Write a summary back into a note (off by default in this design) |

## Proposed connections

1. **Claude Desktop** (local, stdio): proposed entry for `claude_desktop_config.json`:
   ```json
   { "mcpServers": { "speak-away": { "command": "speakaway", "args": ["mcp"] } } }
   ```
2. **ChatGPT** (HTTPS): proposed `speakaway mcp --http` command, with a tunnel and rotating access token.

The design calls for read-only access by default and closing the tunnel when the connector closes. Neither is implemented in the Mac app.
