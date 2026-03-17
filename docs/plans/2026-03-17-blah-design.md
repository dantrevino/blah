# Blah - Design Document

**Date:** 2026-03-17
**Status:** Approved

## Overview

Blah is a Flutter desktop application for running multiple coding agents (Claude, Codex, OpenCode) in parallel with git worktree isolation.

## Goals

1. Run multiple agent instances simultaneously
2. Isolate each agent in its own git worktree
3. Provide a clean terminal UI with ligature and Nerd Font support
4. Persist sessions across app restarts
5. Support Linux, macOS, Windows (Unix-like priority)

## Architecture

### Option B: Flutter Desktop-Only with Embedded Backend

Single Flutter desktop app with embedded backend logic. No separate server process - everything runs in one application using Dart isolates for background work.

### Key Components

1. **UI Layer (Flutter)**
   - Sidebar: List of active agent sessions with status
   - Main area: Terminal emulator displaying agent output
   - Modal: New session dialog (repo path + instructions input)
   - Settings: Agent configs, theme preferences

2. **Session Manager (Dart isolate)**
   - Spawns/terminates agent processes (Claude, Codex, OpenCode)
   - Tracks session state (running, idle, error)
   - Routes terminal I/O between processes and UI

3. **Worktree Manager**
   - Creates git worktrees automatically
   - Manages branch naming scheme
   - Cleans up worktrees when sessions close

4. **Terminal Emulator**
   - libghostty for VT emulation (parsing, buffer, scrollback)
   - Flutter Text widget for rendering (ligatures, Nerd Fonts, GPU acceleration)

### Data Flow

```
User Input → Flutter UI 
           → Session Request (repo path + instructions)
           → Worktree Manager (creates worktree)
           → Session Manager (spawns agent process)
           → Terminal Stream (bidirectional I/O)
```

### Persistence

- SQLite for session history (`~/Documents/blah/sessions/`)
- JSON config file for user preferences (`~/Documents/blah/settings.json`)
- Git worktrees persist on disk at `<repo>/.blah-worktrees/<session-id>/`

## Session Creation Workflow

1. **Click "New Session"** button in sidebar
2. **Modal appears** with:
   - Repository path input (file picker)
   - Agent dropdown: Claude | Codex | OpenCode
   - Instructions text area (multi-line input)
   - Advanced options (collapsed by default):
     - Parent branch selector (default: current branch)
     - Branch name prefix (default: `agent/`)
3. **Click "Start"** → Session creation begins

### Auto-Workflow Steps

```
1. Validate repo path (must be git repository)
2. Generate unique session ID (UUID)
3. Create git worktree:
   - Branch name: {prefix}/{session-id}
   - Parent branch: selected or current
   - Command: git worktree add -b {branch} {path}
4. Initialize terminal process:
   - Change directory to worktree
   - Spawn agent process with session ID
   - For Claude: claude --session-id {uuid}
   - For Codex: codex --session-id {uuid}
   - For OpenCode: opencode --session-id {uuid}
5. Stream output to terminal widget
6. Add session to sidebar list
```

### Agent Process Configuration

Each agent launched with:
- Working directory: worktree path
- Session ID: passed as flag
- Instructions: piped to stdin OR passed as file
- Config path: `--config ~/.config/{agent}/config.yaml`

### Instructions Handling

User instructions passed via stdin:
```bash
< instructions.txt claude --session-id {uuid}
```

Or temporary file if agent supports file input.

## UI Layout

### Main Window Structure

```
┌─────────────────────────────────────────────────────────┐
│  blah                           [─] [□] [×]              │
├─────────────┬───────────────────────────────────────────┤
│   SIDEBAR   │            TERMINAL AREA                  │
│             │                                           │
│  [+ New]    │  ┌─────────────────────────────────────┐  │
│             │  │ $ claude --session-id abc-123       │  │
│  Sessions   │  │ ✓ Ready to receive instructions      │  │
│  ┌───────┐  │  │                                      │  │
│  │ ● #1  │  │  │ > Implement user authentication     │  │
│  │   auth│  │  │                                      │  │
│  ├───────┤  │  │ I'll help you implement user auth.  │  │
│  │ ○ #2  │  │  │ Let me start by examining the        │  │
│  │   feat│  │  │ existing codebase...                  │  │
│  ├───────┤  │  │                                      │  │
│  │ ○ #3  │  │  │ [Reading src/auth.ts...]            │  │
│  │   docs│  │  │                                      │  │
│  └───────┘  │  └─────────────────────────────────────┘  │
│             │                                           │
│  [⚙️]       │                                           │
└─────────────┴───────────────────────────────────────────┘
```

### Sidebar Components

- **New Session Button** (top): `+` icon, opens modal
- **Session List**: Scrollable list of session cards
  - Status indicator: `●` (running), `○` (idle), `⚠` (error)
  - Session number: `#1`, `#2`, etc.
  - Short name: auto-generated or user-defined
  - Click → loads terminal in main area
- **Settings Button** (bottom): `⚙️` icon

### Session Card Widget

```dart
class SessionCard extends StatelessWidget {
  final Session session;
  final bool isActive;
  
  // Shows:
  // - Status dot (green running, grey idle, red error)
  // - Session number
  // - Branch name (truncated)
  // - Agent icon (Claude/Codex/OpenCode logo)
  // - Context menu: Rename, Close, Delete worktree
}
```

### New Session Modal

```
┌─────────────────────────────────────────┐
│  New Session                             │
│                                          │
│  Repository Path                         │
│  [/home/dan/projects/myapp] [Browse]    │
│                                          │
│  Coding Agent                             │
│  [Claude ▼]                              │
│                                          │
│  Instructions                             │
│  ┌─────────────────────────────────────┐│
│  │ Implement user login with JWT tokens  ││
│  │ Include password hashing and session  ││
│  │ management. Follow existing patterns   ││
│  │ in src/auth/                          ││
│  └─────────────────────────────────────┘│
│                                          │
│  ▼ Advanced Options                       │
│                                          │
│  [Cancel]             [Start Session]     │
└─────────────────────────────────────────┘
```

## Terminal Rendering

### libghostty Integration

libghostty provides VT emulation (parsing, state). Flutter Text widget handles rendering.

```dart
import 'package:libghostty/libghostty.dart';

class TerminalView extends StatefulWidget {
  final Terminal terminal;
  final TextStyle Function(TerminalStyle)? styleBuilder;
  
  @override
  State<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends State<TerminalView> {
  late TextEditingController _inputController;
  late FocusNode _focusNode;
  
  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
    _focusNode = FocusNode();
    
    // Listen for terminal buffer changes
    widget.terminal.onWrite = () {
      if (mounted) setState(() {});
    };
  }
  
  // ... rendering logic
}
```

### Font Configuration

```yaml
# pubspec.yaml
flutter:
  fonts:
    - family: JetBrains Mono
      fonts:
        - asset: assets/fonts/JetBrainsMono-Regular.ttf
        - asset: assets/fonts/JetBrainsMono-Bold.ttf
          weight: 700
```

### Terminal Theme

```dart
class TerminalTheme {
  final String name;
  final Color background;
  final Color foreground;
  final Color cursor;
  final Map<int, Color> ansiColors;
  
  static TerminalTheme builtin(String name) {
    switch (name) {
      case 'dark':
        return TerminalTheme(...);
      case 'light':
        return TerminalTheme(...);
      case 'dracula':
        return TerminalTheme(...);
    }
  }
}
```

## Process Management

### Session Manager (Dart Isolate)

```dart
class SessionManager {
  final Map<String, AgentSession> _sessions = {};
  final SendPort _mainIsolatePort;
  
  Future<AgentSession> createSession({
    required String id,
    required String repoPath,
    required String agentType,
    required String instructions,
    required String branchPrefix,
    String? parentBranch,
  }) async {
    // 1. Validate repo
    // 2. Create git worktree
    // 3. Spawn agent process
    // 4. Create terminal
    // 5. Wire up I/O
    // 6. Write initial instructions
  }
  
  Future<Process> _spawnAgent({
    required String agentType,
    required String worktreePath,
    required String sessionId,
  }) async {
    final commands = {
      'claude': ['claude', '--session-id', sessionId],
      'codex': ['codex', '--session-id', sessionId],
      'opencode': ['opencode', '--session-id', sessionId],
    };
    
    return await Process.start(
      cmd[0],
      cmd.sublist(1),
      workingDirectory: worktreePath,
      environment: {
        'TERM': 'xterm-256color',
        'COLORTERM': 'truecolor',
      },
    );
  }
  
  Future<String> _createWorktree({
    required String repoPath,
    required String sessionBranch,
    String? parentBranch,
  }) async {
    final worktreesDir = '$repoPath/.blah-worktrees';
    final worktreePath = '$worktreesDir/$sessionBranch';
    
    await Directory(worktreesDir).create(recursive: true);
    
    parentBranch ??= await _getCurrentBranch(repoPath);
    
    final result = await Process.run(
      'git',
      ['worktree', 'add', '-b', sessionBranch, worktreePath, parentBranch],
      workingDirectory: repoPath,
    );
    
    if (result.exitCode != 0) {
      throw Exception('Failed to create worktree: ${result.stderr}');
    }
    
    return worktreePath;
  }
}
```

## State Management

### Data Models

```dart
enum AgentType { claude, codex, opencode }
enum SessionStatus { starting, running, idle, error, terminated }

class Session {
  final String id;
  final int number;
  final String name;
  final String repoPath;
  final String worktreePath;
  final String gitBranch;
  final AgentType agentType;
  final SessionStatus status;
  final String? instructions;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  
  // ... toJson/fromJson
}
```

### App State (Provider)

```dart
class AppState extends ChangeNotifier {
  final List<Session> _sessions = [];
  final Map<String, Terminal> _terminals = {};
  String? _activeSessionId;
  
  List<Session> get sessions => List.unmodifiable(_sessions);
  Session? get activeSession => _activeSessionId != null 
    ? _sessions.firstWhereOrNull((s) => s.id == _activeSessionId) 
    : null;
  
  Future<void> createSession({...}) async {
    // Create worktree, spawn process, add to list
  }
  
  Future<void> closeSession(String sessionId) async {
    // Kill process, dispose terminal, remove from list, clean worktree
  }
}
```

## Persistence

### Session Store

```dart
class SessionStore {
  Future<String> get _sessionsDir async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/blah/sessions';
  }
  
  Future<void> save(Session session) async {
    final dir = await _sessionsDir;
    await Directory(dir).create(recursive: true);
    
    final file = File('$dir/${session.id}.json');
    await file.writeAsString(jsonEncode(session.toJson()));
  }
  
  Future<List<Session>> loadAll() async {
    // Load all session JSON files from ~/Documents/blah/sessions/
  }
}
```

### Settings Store

```dart
class SettingsStore {
  Future<String> get _settingsPath async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/blah/settings.json';
  }
  
  Future<Settings> load() async {
    // Load from ~/Documents/blah/settings.json
    // Return defaults if not exists
  }
  
  Future<void> save(Settings settings) async {
    // Save to ~/Documents/blah/settings.json
  }
}
```

## Error Handling

### Error Categories

```dart
enum ErrorCode {
  gitNotFound,
  notAGitRepo,
  worktreeCreationFailed,
  agentNotFound,
  processSpawnFailed,
  invalidRepoPath,
  sessionCorrupted,
  terminalInitFailed,
}

class BlahError implements Exception {
  final ErrorCode code;
  final String message;
  final String? details;
  final String? recoveryHint;
}
```

### Recovery Strategies

- **Corrupted session**: Prompt user to delete or recreate
- **Process crash**: Offer restart option
- **Worktree conflict**: Offer cleanup or alternative branch
- **Agent not found**: Provide install instructions with links

### Git Pre-flight Checks

```dart
class GitChecker {
  static Future<void> verifyGitAvailable() async {
    // Check git in PATH
  }
  
  static Future<void> verifyRepo(String path) async {
    // Check if valid git repository
  }
  
  static Future<String> getCurrentBranch(String path) async {
    // Get current branch name
  }
}
```

### Agent Availability Check

```dart
class AgentChecker {
  static Future<Map<AgentType, bool>> checkAvailability() async {
    return {
      AgentType.claude: await _checkCommand('claude'),
      AgentType.codex: await _checkCommand('codex'),
      AgentType.opencode: await _checkCommand('opencode'),
    };
  }
}
```

## Settings

### Settings Model

```dart
class Settings {
  final AppSettings app;
  final TerminalSettings terminal;
  final AgentSettings agents;
}

class AppSettings {
  final String branchPrefix;        // default: 'agent'
  final bool autoCleanupWorktrees;  // default: true
  final bool confirmOnClose;         // default: true
}

class TerminalSettings {
  final String fontFamily;        // default: 'JetBrains Mono'
  final double fontSize;          // default: 14
  final double lineHeight;        // default: 1.4
  final TerminalTheme theme;      // default: 'Dark'
  final bool ligaturesEnabled;    // default: true
  final int scrollbackLines;      // default: 10000
  final bool cursorBlink;         // default: true
}

class AgentSettings {
  final Map<AgentType, AgentConfig> configs;
}

class AgentConfig {
  final String executable;
  final List<String> defaultArgs;
  final Map<String, String> env;
  final String? configPath;
}
```

## Project Structure

```
blah/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── models/
│   │   ├── session.dart
│   │   ├── settings.dart
│   │   └── errors.dart
│   ├── state/
│   │   ├── app_state.dart
│   │   └── settings_state.dart
│   ├── services/
│   │   ├── session_manager.dart
│   │   ├── session_store.dart
│   │   ├── settings_store.dart
│   │   ├── git_checker.dart
│   │   ├── agent_checker.dart
│   │   ├── recovery_manager.dart
│   │   └── isolate_channel.dart
│   ├── ui/
│   │   ├── home/
│   │   │   ├── home_screen.dart
│   │   │   ├── sidebar.dart
│   │   │   └── session_list.dart
│   │   ├── terminal/
│   │   │   ├── terminal_view.dart
│   │   │   ├── terminal_theme.dart
│   │   │   └── terminal_input.dart
│   │   ├── session/
│   │   │   ├── new_session_dialog.dart
│   │   │   ├── session_card.dart
│   │   │   └── session_context_menu.dart
│   │   ├── settings/
│   │   │   ├── settings_dialog.dart
│   │   │   ├── app_tab.dart
│   │   │   ├── terminal_tab.dart
│   │   │   └── agents_tab.dart
│   │   └── widgets/
│   │       ├── icon_button.dart
│   │       └── status_indicator.dart
│   ├── errors/
│   │   └── errors.dart
│   └── utils/
│       ├── constants.dart
│       └── logger.dart
├── assets/
│   └── fonts/
│       ├── JetBrainsMono-Regular.ttf
│       ├── JetBrainsMono-Bold.ttf
│       ├── FiraCode-Regular.ttf
│       └── FiraCode-Bold.ttf
├── linux/
├── macos/
├── windows/
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
```

## Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.0
  libghostty: ^0.0.4
  path_provider: ^2.1.0
  uuid: ^4.0.0
  file_selector: ^1.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```

## Build Commands

```bash
# Development
flutter run -d linux    # or -d macos / -d windows

# Build release
flutter build linux --release
flutter build macos --release
flutter build windows --release
```

## Platform Notes

### Linux
- Requires Flutter 3.6+ for proper Linux embedding
- PTY support via `/dev/ptmx`

### macOS
- Requires entitlements for filesystem access
- PTY support via `openpty`

### Windows
- Requires Visual Studio build tools
- ConPTY for terminal emulation

## File Paths

- Sessions: `~/Documents/blah/sessions/<id>.json`
- Settings: `~/Documents/blah/settings.json`
- Worktrees: `<repo>/.blah-worktrees/<session-id>/`

## Next Steps

1. Initialize Flutter project
2. Add dependencies to pubspec.yaml
3. Implement models (Session, Settings, Errors)
4. Implement services (SessionManager, Stores, Checkers)
5. Implement state (AppState, SettingsState)
6. Build UI components
7. Integrate libghostty terminal
8. Test session creation flow
9. Test session persistence
10. Test across Linux, macOS, Windows