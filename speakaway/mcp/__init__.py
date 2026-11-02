"""MCP server so ChatGPT, Claude and other clients can read Speak Away notes (roadmap 0.5).

Transports:
  stdio  for Claude Desktop, Cursor and other local clients
  http   for ChatGPT, which only reaches remote HTTPS servers: localhost + tunnel + token

Tools (read-only unless config [mcp] write_tools = true):
"""

TOOLS = {
    "list_notes": "Recent meetings and dictations, newest first",
    "get_note": "One full note by id",
    "search_notes": "Full-text search across all notes",
    "get_live_transcript": "Transcript of the meeting in progress",
}

WRITE_TOOLS = {
    "save_summary": "Write a summary into a note, above the transcript",
}
