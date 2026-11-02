# Security and privacy

- Audio is processed on your computer. With the default settings nothing leaves it.
- Meeting audio is deleted once it is transcribed, unless you choose to keep it.
- API keys are stored in the macOS Keychain and sent only to the provider they belong to.
- The MCP connector is read-only by default. When exposed over HTTP it requires a token, and it only listens on localhost unless you open a tunnel yourself.
- Recording other people may require their consent where you live. The notetaker shows a visible indicator while it records and can post a notice in the meeting chat.

Report a vulnerability by opening a private security advisory on GitHub.
