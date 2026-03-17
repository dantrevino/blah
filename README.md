# blah

Run multiple coding agent instances (Claude, Codex, OpenCode) in parallel with git worktree isolation.

## Features

- Multiple parallel agent sessions
- Git worktree isolation per session
- libghostty terminal with ligature support
- Session persistence across restarts
- Linux, macOS, Windows support

## Prerequisites

- Flutter 3.0+
- Git
- Claude CLI, Codex CLI, or OpenCode CLI

## Installation

```bash
flutter pub get
flutter run -d linux  # or macos, windows
```

## Usage

1. Click `+` in sidebar
2. Select a git repository
3. Choose coding agent (Claude/Codex/OpenCode)
4. Enter instructions for the agent
5. Session starts in isolated worktree

## Architecture

- **libghostty**: Terminal emulation (VT parsing, buffer)
- **Flutter Text**: GPU-accelerated rendering with ligatures
- **Dart isolates**: Process management without blocking UI
- **Provider**: State management

## File Paths

- Sessions: `~/Documents/blah/sessions/`
- Settings: `~/Documents/blah/settings.json`
- Worktrees: `<repo>/.blah-worktrees/<session-id>/`