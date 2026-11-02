"""`speakaway dictate | notes | mcp`. Commands are placeholders until each roadmap step lands."""

import argparse
import sys

COMMANDS = {
    "dictate": "Dictation (roadmap 0.1, porting from whisper-flow)",
    "notes": "Meeting notetaker (roadmap 0.3)",
    "mcp": "MCP server for ChatGPT and Claude (roadmap 0.5)",
}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="speakaway", description="Speak Away")
    parser.add_argument("command", choices=sorted(COMMANDS))
    args = parser.parse_args(argv)
    print(f"Not built yet: {COMMANDS[args.command]}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
