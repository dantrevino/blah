# Blah Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Flutter desktop app for running multiple coding agents (Claude, Codex, OpenCode) in parallel with git worktree isolation.

**Architecture:** Single Flutter desktop app with Dart isolates for process management. libghostty for terminal emulation, Provider for state management, file-based persistence for sessions and settings.

**Tech Stack:** Flutter 3.0+, Dart isolates, libghostty ^0.0.4, provider ^6.1.0, path_provider ^2.1.0

---

## Task 1: Initialize Flutter Project

**Files:**
- Create: `pubspec.yaml`
- Create: `analysis_options.yaml`
- Create: `lib/main.dart`

**Step 1: Create Flutter project**

Run: `flutter create --project-name blah --org com.blah --platforms linux,macos,windows .`

Expected: Flutter project created with `pubspec.yaml`, `lib/main.dart`, platform directories

**Step 2: Update pubspec.yaml dependencies**

Replace `pubspec.yaml` with:

```yaml
name: blah
description: Run multiple coding agent instances in parallel with git worktree isolation
version: 1.0.0

environment:
  sdk: '>=3.0.0 <4.0.0'

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

flutter:
  uses-material-design: true
  fonts:
    - family: JetBrains Mono
      fonts:
        - asset: assets/fonts/JetBrainsMono-Regular.ttf
        - asset: assets/fonts/JetBrainsMono-Bold.ttf
          weight: 700
    - family: Fira Code
      fonts:
        - asset: assets/fonts/FiraCode-Regular.ttf
        - asset: assets/fonts/FiraCode-Bold.ttf
          weight: 700
```

**Step 3: Create analysis_options.yaml**

Create `analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_single_quotes: true
    prefer_const_declarations: true
    avoid_print: false
```

**Step 4: Create assets directory structure**

Run:
```bash
mkdir -p assets/fonts
touch assets/fonts/.gitkeep
```

**Step 5: Download fonts (manual)**

Download JetBrains Mono and Fira Code fonts from:
- https://www.jetbrains.com/lp/mono/
- https://github.com/tonsky/FiraCode

Place files in `assets/fonts/`:
- JetBrainsMono-Regular.ttf
- JetBrainsMono-Bold.ttf
- FiraCode-Regular.ttf
- FiraCode-Bold.ttf

**Step 6: Initialize git**

Run:
```bash
git init
git add .
git commit -m "init: flutter project scaffold"
```

---

## Task 2: Create Error Models

**Files:**
- Create: `lib/errors/errors.dart`

**Step 1: Create error types**

Create `lib/errors/errors.dart`:

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

  BlahError(
    this.code, {
    required this.message,
    this.details,
    this.recoveryHint,
  });

  @override
  String toString() => 'BlahError: $message';
}
```

**Step 2: Commit**

```bash
git add lib/errors/errors.dart
git commit -m "feat: add error types and error model"
```

---

## Task 3: Create Session Model

**Files:**
- Create: `lib/models/session.dart`

**Step 1: Create Session model**

Create `lib/models/session.dart`:

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

  Session({
    required this.id,
    required this.number,
    required this.name,
    required this.repoPath,
    required this.worktreePath,
    required this.gitBranch,
    required this.agentType,
    this.status = SessionStatus.starting,
    this.instructions,
    DateTime? createdAt,
    DateTime? lastActiveAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastActiveAt = lastActiveAt ?? DateTime.now();

  Session copyWith({
    SessionStatus? status,
    String? name,
    DateTime? lastActiveAt,
  }) {
    return Session(
      id: id,
      number: number,
      name: name ?? this.name,
      repoPath: repoPath,
      worktreePath: worktreePath,
      gitBranch: gitBranch,
      agentType: agentType,
      status: status ?? this.status,
      instructions: instructions,
      createdAt: createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'name': name,
      'repoPath': repoPath,
      'worktreePath': worktreePath,
      'gitBranch': gitBranch,
      'agentType': agentType.name,
      'status': status.name,
      'instructions': instructions,
      'createdAt': createdAt.toIso8601String(),
      'lastActiveAt': lastActiveAt.toIso8601String(),
    };
  }

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'],
      number: json['number'],
      name: json['name'],
      repoPath: json['repoPath'],
      worktreePath: json['worktreePath'],
      gitBranch: json['gitBranch'],
      agentType: AgentType.values.byName(json['agentType']),
      status: SessionStatus.values.byName(json['status']),
      instructions: json['instructions'],
      createdAt: DateTime.parse(json['createdAt']),
      lastActiveAt: DateTime.parse(json['lastActiveAt']),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/models/session.dart
git commit -m "feat: add Session model with serialization"
```

---

## Task 4: Create Settings Models

**Files:**
- Create: `lib/models/settings.dart`

**Step 1: Create Settings models**

Create `lib/models/settings.dart`:

```dart
import 'package:flutter/material.dart';

class Settings {
  final AppSettings app;
  final TerminalSettings terminal;
  final AgentSettings agents;

  Settings({
    AppSettings? app,
    TerminalSettings? terminal,
    AgentSettings? agents,
  })  : app = app ?? AppSettings.defaults(),
        terminal = terminal ?? TerminalSettings.defaults(),
        agents = agents ?? AgentSettings.defaults();

  Settings copyWith({
    AppSettings? app,
    TerminalSettings? terminal,
    AgentSettings? agents,
  }) {
    return Settings(
      app: app ?? this.app,
      terminal: terminal ?? this.terminal,
      agents: agents ?? this.agents,
    );
  }

  Map<String, dynamic> toJson() => {
        'app': app.toJson(),
        'terminal': terminal.toJson(),
        'agents': agents.toJson(),
      };

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      app: json['app'] != null ? AppSettings.fromJson(json['app']) : null,
      terminal: json['terminal'] != null
          ? TerminalSettings.fromJson(json['terminal'])
          : null,
      agents: json['agents'] != null
          ? AgentSettings.fromJson(json['agents'])
          : null,
    );
  }
}

class AppSettings {
  final String branchPrefix;
  final bool autoCleanupWorktrees;
  final bool confirmOnClose;

  AppSettings({
    required this.branchPrefix,
    required this.autoCleanupWorktrees,
    required this.confirmOnClose,
  });

  factory AppSettings.defaults() => AppSettings(
        branchPrefix: 'agent',
        autoCleanupWorktrees: true,
        confirmOnClose: true,
      );

  Map<String, dynamic> toJson() => {
        'branchPrefix': branchPrefix,
        'autoCleanupWorktrees': autoCleanupWorktrees,
        'confirmOnClose': confirmOnClose,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      branchPrefix: json['branchPrefix'] ?? 'agent',
      autoCleanupWorktrees: json['autoCleanupWorktrees'] ?? true,
      confirmOnClose: json['confirmOnClose'] ?? true,
    );
  }

  AppSettings copyWith({
    String? branchPrefix,
    bool? autoCleanupWorktrees,
    bool? confirmOnClose,
  }) {
    return AppSettings(
      branchPrefix: branchPrefix ?? this.branchPrefix,
      autoCleanupWorktrees:
          autoCleanupWorktrees ?? this.autoCleanupWorktrees,
      confirmOnClose: confirmOnClose ?? this.confirmOnClose,
    );
  }
}

class TerminalSettings {
  final String fontFamily;
  final double fontSize;
  final double lineHeight;
  final String themeName;
  final bool ligaturesEnabled;
  final int scrollbackLines;
  final bool cursorBlink;

  TerminalSettings({
    required this.fontFamily,
    required this.fontSize,
    required this.lineHeight,
    required this.themeName,
    required this.ligaturesEnabled,
    required this.scrollbackLines,
    required this.cursorBlink,
  });

  factory TerminalSettings.defaults() => TerminalSettings(
        fontFamily: 'JetBrains Mono',
        fontSize: 14,
        lineHeight: 1.4,
        themeName: 'dark',
        ligaturesEnabled: true,
        scrollbackLines: 10000,
        cursorBlink: true,
      );

  Map<String, dynamic> toJson() => {
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'themeName': themeName,
        'ligaturesEnabled': ligaturesEnabled,
        'scrollbackLines': scrollbackLines,
        'cursorBlink': cursorBlink,
      };

  factory TerminalSettings.fromJson(Map<String, dynamic> json) {
    return TerminalSettings(
      fontFamily: json['fontFamily'] ?? 'JetBrains Mono',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 14,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.4,
      themeName: json['themeName'] ?? 'dark',
      ligaturesEnabled: json['ligaturesEnabled'] ?? true,
      scrollbackLines: json['scrollbackLines'] ?? 10000,
      cursorBlink: json['cursorBlink'] ?? true,
    );
  }

  TerminalSettings copyWith({
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
    String? themeName,
    bool? ligaturesEnabled,
    int? scrollbackLines,
    bool? cursorBlink,
  }) {
    return TerminalSettings(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      themeName: themeName ?? this.themeName,
      ligaturesEnabled: ligaturesEnabled ?? this.ligaturesEnabled,
      scrollbackLines: scrollbackLines ?? this.scrollbackLines,
      cursorBlink: cursorBlink ?? this.cursorBlink,
    );
  }
}

class AgentSettings {
  final Map<String, AgentConfig> configs;

  AgentSettings({required this.configs});

  factory AgentSettings.defaults() => AgentSettings(
        configs: {
          'claude': AgentConfig(
            executable: 'claude',
            defaultArgs: ['--session-id'],
            env: {},
          ),
          'codex': AgentConfig(
            executable: 'codex',
            defaultArgs: ['--session-id'],
            env: {},
          ),
          'opencode': AgentConfig(
            executable: 'opencode',
            defaultArgs: ['--session-id'],
            env: {},
          ),
        },
      );

  AgentConfig getConfig(String agentType) {
    return configs[agentType] ?? configs['claude']!;
  }

  Map<String, dynamic> toJson() => {
        'configs': configs.map((key, value) => MapEntry(key, value.toJson())),
      };

  factory AgentSettings.fromJson(Map<String, dynamic> json) {
    final configs = <String, AgentConfig>{};
    if (json['configs'] != null) {
      (json['configs'] as Map<String, dynamic>).forEach((key, value) {
        configs[key] = AgentConfig.fromJson(value as Map<String, dynamic>);
      });
    }
    return AgentSettings(configs: configs);
  }
}

class AgentConfig {
  final String executable;
  final List<String> defaultArgs;
  final Map<String, String> env;
  final String? configPath;

  AgentConfig({
    required this.executable,
    required this.defaultArgs,
    required this.env,
    this.configPath,
  });

  Map<String, dynamic> toJson() => {
        'executable': executable,
        'defaultArgs': defaultArgs,
        'env': env,
        'configPath': configPath,
      };

  factory AgentConfig.fromJson(Map<String, dynamic> json) {
    final env = <String, String>{};
    if (json['env'] != null) {
      (json['env'] as Map<String, dynamic>)
          .forEach((key, value) => env[key] = value as String);
    }
    return AgentConfig(
      executable: json['executable'] ?? 'claude',
      defaultArgs: (json['defaultArgs'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          ['--session-id'],
      env: env,
      configPath: json['configPath'] as String?,
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/models/settings.dart
git commit -m "feat: add Settings models with serialization"
```

---

## Task 5: Create Session Store

**Files:**
- Create: `lib/services/session_store.dart`

**Step 1: Create SessionStore service**

Create `lib/services/session_store.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/session.dart';

class SessionStore {
  Future<String> get _sessionsDir async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/blah/sessions';
  }

  Future<void> save(Session session) async {
    final dir = await _sessionsDir;
    await Directory(dir).create(recursive: true);

    final file = File('$dir/${session.id}.json');
    await file.writeAsString(
      JsonEncoder.withIndent('  ').convert(session.toJson()),
    );
  }

  Future<Session?> load(String sessionId) async {
    final dir = await _sessionsDir;
    final file = File('$dir/$sessionId.json');

    if (!await file.exists()) return null;

    try {
      final json = jsonDecode(await file.readAsString());
      return Session.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  Future<List<Session>> loadAll() async {
    final dir = await _sessionsDir;
    final directory = Directory(dir);

    if (!await directory.exists()) return [];

    final files = await directory
        .list()
        .where((entity) => entity.path.endsWith('.json'))
        .toList();

    final sessions = await Future.wait(
      files.map((file) async {
        try {
          final json = jsonDecode(await File(file.path).readAsString());
          return Session.fromJson(json as Map<String, dynamic>);
        } catch (e) {
          return null;
        }
      }),
    );

    return sessions
        .whereType<Session>()
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> delete(String sessionId) async {
    final dir = await _sessionsDir;
    final file = File('$dir/$sessionId.json');
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> markCorrupted(String sessionId) async {
    final dir = await _sessionsDir;
    final file = File('$dir/$sessionId.json');
    if (await file.exists()) {
      final corruptedFile = File('$dir/${sessionId}.corrupted.json');
      await file.rename(corruptedFile.path);
    }
  }
}
```

**Step 2: Commit**

```bash
git add lib/services/session_store.dart
git commit -m "feat: add SessionStore for persistence"
```

---

## Task 6: Create Settings Store

**Files:**
- Create: `lib/services/settings_store.dart`

**Step 1: Create SettingsStore service**

Create `lib/services/settings_store.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/settings.dart';

class SettingsStore {
  static const String _fileName = 'settings.json';

  Future<String> get _settingsPath async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/blah/$_fileName';
  }

  Future<Settings> load() async {
    final path = await _settingsPath;
    final file = File(path);

    if (!await file.exists()) {
      return Settings();
    }

    try {
      final json = jsonDecode(await file.readAsString());
      return Settings.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      return Settings();
    }
  }

  Future<void> save(Settings settings) async {
    final path = await _settingsPath;
    final file = File(path);

    await file.parent.create(recursive: true);
    await file.writeAsString(
      JsonEncoder.withIndent('  ').convert(settings.toJson()),
    );
  }

  Future<void> reset() async {
    final path = await _settingsPath;
    final file = File(path);

    if (await file.exists()) {
      await file.delete();
    }
  }
}
```

**Step 2: Commit**

```bash
git add lib/services/settings_store.dart
git commit -m "feat: add SettingsStore for persistence"
```

---

## Task 7: Create Git Checker Service

**Files:**
- Create: `lib/services/git_checker.dart`

**Step 1: Create GitChecker service**

Create `lib/services/git_checker.dart`:

```dart
import 'dart:io';
import '../errors/errors.dart';

class GitChecker {
  static Future<void> verifyGitAvailable() async {
    final result = await Process.run('git', ['--version']);

    if (result.exitCode != 0) {
      throw BlahError(
        ErrorCode.gitNotFound,
        message: 'Git is not installed or not in PATH',
        recoveryHint: 'Install Git from https://git-scm.com/downloads',
      );
    }
  }

  static Future<void> verifyRepo(String path) async {
    if (!await Directory(path).exists()) {
      throw BlahError(
        ErrorCode.invalidRepoPath,
        message: 'Path does not exist: $path',
      );
    }

    final result = await Process.run(
      'git',
      ['rev-parse', '--is-inside-work-tree'],
      workingDirectory: path,
    );

    if (result.exitCode != 0) {
      throw BlahError(
        ErrorCode.notAGitRepo,
        message: 'Not a git repository: $path',
        recoveryHint: 'Initialize with: git init',
      );
    }
  }

  static Future<String> getCurrentBranch(String path) async {
    final result = await Process.run(
      'git',
      ['rev-parse', '--abbrev-ref', 'HEAD'],
      workingDirectory: path,
    );

    if (result.exitCode != 0) {
      return 'main';
    }

    return result.stdout.toString().trim();
  }

  static Future<bool> branchExists(String path, String branchName) async {
    final result = await Process.run(
      'git',
      ['branch', '--list', branchName],
      workingDirectory: path,
    );

    return result.stdout.toString().trim().isNotEmpty;
  }
}
```

**Step 2: Commit**

```bash
git add lib/services/git_checker.dart
git commit -m "feat: add GitChecker for pre-flight validation"
```

---

## Task 8: Create Agent Checker Service

**Files:**
- Create: `lib/services/agent_checker.dart`

**Step 1: Create AgentChecker service**

Create `lib/services/agent_checker.dart`:

```dart
import 'dart:io';
import '../models/session.dart';

class AgentChecker {
  static Future<Map<AgentType, bool>> checkAvailability() async {
    final results = <AgentType, bool>{};

    for (final agentType in AgentType.values) {
      results[agentType] = await _checkCommand(_getExecutable(agentType));
    }

    return results;
  }

  static Future<bool> isAvailable(AgentType agentType) async {
    return _checkCommand(_getExecutable(agentType));
  }

  static String getInstallHint(AgentType type) {
    switch (type) {
      case AgentType.claude:
        return 'npm install -g @anthropic-ai/claude-cli';
      case AgentType.codex:
        return 'npm install -g @openai/codex-cli';
      case AgentType.opencode:
        return 'See: https://github.com/opencode/opencode';
    }
  }

  static String _getExecutable(AgentType agentType) {
    switch (agentType) {
      case AgentType.claude:
        return 'claude';
      case AgentType.codex:
        return 'codex';
      case AgentType.opencode:
        return 'opencode';
    }
  }

  static Future<bool> _checkCommand(String command) async {
    final result = await Process.run('which', [command]);
    return result.exitCode == 0;
  }
}
```

**Step 2: Commit**

```bash
git add lib/services/agent_checker.dart
git commit -m "feat: add AgentChecker for availability detection"
```

---

## Task 9: Create Session Manager Isolate

**Files:**
- Create: `lib/services/session_manager.dart`

**Step 1: Create SessionManager service**

Create `lib/services/session_manager.dart`:

```dart
import 'dart:async';
import 'dart:io';
import 'package:libghostty/libghostty.dart';
import 'package:uuid/uuid.dart';
import '../errors/errors.dart';
import '../models/session.dart';
import 'git_checker.dart';

class AgentSession {
  final String id;
  final Process process;
  final Terminal terminal;
  final String worktreePath;
  final AgentType agentType;
  DateTime createdAt;

  AgentSession({
    required this.id,
    required this.process,
    required this.terminal,
    required this.worktreePath,
    required this.agentType,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class SessionManager {
  final Map<String, AgentSession> _sessions = {};
  final void Function(Map<String, dynamic>)? onMessage;

  SessionManager({this.onMessage});

  Future<AgentSession> createSession({
    required String id,
    required String repoPath,
    required AgentType agentType,
    required String instructions,
    required String branchPrefix,
    String? parentBranch,
  }) async {
    // Validate repo
    await GitChecker.verifyRepo(repoPath);

    // Create git worktree
    final worktreePath = await _createWorktree(
      repoPath: repoPath,
      sessionBranch: '$branchPrefix/$id',
      parentBranch: parentBranch,
    );

    // Spawn agent process
    final process = await _spawnAgent(
      agentType: agentType,
      worktreePath: worktreePath,
      sessionId: id,
    );

    // Create terminal
    final terminal = Terminal(cols: 120, rows: 40);

    // Wire up I/O
    _wireProcessIO(id, process, terminal);

    // Write instructions
    if (instructions.isNotEmpty) {
      process.stdin.writeln(instructions);
    }

    final session = AgentSession(
      id: id,
      process: process,
      terminal: terminal,
      worktreePath: worktreePath,
      agentType: agentType,
    );

    _sessions[id] = session;
    return session;
  }

  void _wireProcessIO(
    String sessionId,
    Process process,
    Terminal terminal,
  ) {
    process.stdout.listen((data) {
      terminal.write(data);
      onMessage?.call({
        'type': 'output',
        'sessionId': sessionId,
        'data': data,
      });
    });

    process.stderr.listen((data) {
      terminal.write(data);
      onMessage?.call({
        'type': 'error',
        'sessionId': sessionId,
        'data': data,
      });
    });

    process.exitCode.then((code) {
      onMessage?.call({
        'type': 'exit',
        'sessionId': sessionId,
        'code': code,
      });
      _sessions.remove(sessionId);
    });
  }

  Future<Process> _spawnAgent({
    required AgentType agentType,
    required String worktreePath,
    required String sessionId,
  }) async {
    final commands = {
      AgentType.claude: ['claude', '--session-id', sessionId],
      AgentType.codex: ['codex', '--session-id', sessionId],
      AgentType.opencode: ['opencode', '--session-id', sessionId],
    };

    final cmd = commands[agentType]!;
    final executable = cmd[0];
    final args = cmd.sublist(1);

    try {
      return await Process.start(
        executable,
        args,
        workingDirectory: worktreePath,
        environment: {
          'TERM': 'xterm-256color',
          'COLORTERM': 'truecolor',
        },
      );
    } catch (e) {
      throw BlahError(
        ErrorCode.processSpawnFailed,
        message: 'Failed to spawn ${agentType.name}',
        details: e.toString(),
        recoveryHint: 'Ensure ${agentType.name} is installed and in PATH',
      );
    }
  }

  Future<String> _createWorktree({
    required String repoPath,
    required String sessionBranch,
    String? parentBranch,
  }) async {
    final worktreesDir = '$repoPath/.blah-worktrees';
    final worktreePath = '$worktreesDir/$sessionBranch';

    await Directory(worktreesDir).create(recursive: true);

    parentBranch ??= await GitChecker.getCurrentBranch(repoPath);

    final result = await Process.run(
      'git',
      ['worktree', 'add', '-b', sessionBranch, worktreePath, parentBranch!],
      workingDirectory: repoPath,
    );

    if (result.exitCode != 0) {
      throw BlahError(
        ErrorCode.worktreeCreationFailed,
        message: 'Failed to create worktree',
        details: result.stderr.toString(),
      );
    }

    return worktreePath;
  }

  Future<void> terminateSession(String sessionId) async {
    final session = _sessions[sessionId];
    if (session == null) return;

    session.process.kill(ProcessSignal.sigterm);
    session.terminal.dispose();
    _sessions.remove(sessionId);
  }

  Future<void> cleanupWorktree(String worktreePath, String repoPath) async {
    await Process.run(
      'git',
      ['worktree', 'remove', worktreePath, '--force'],
      workingDirectory: repoPath,
    );
  }

  void sendInput(String sessionId, String input) {
    final session = _sessions[sessionId];
    if (session != null) {
      session.process.stdin.write(input);
    }
  }

  AgentSession? getSession(String sessionId) => _sessions[sessionId];
}
```

**Step 2: Commit**

```bash
git add lib/services/session_manager.dart
git commit -m "feat: add SessionManager for process management"
```

---

## Task 10: Create App State

**Files:**
- Create: `lib/state/app_state.dart`

**Step 1: Create AppState provider**

Create `lib/state/app_state.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:libghostty/libghostty.dart';
import 'package:uuid/uuid.dart';
import '../models/session.dart';
import '../services/session_store.dart';
import '../services/session_manager.dart';

class AppState extends ChangeNotifier {
  final List<Session> _sessions = [];
  final Map<String, Terminal> _terminals = {};
  String? _activeSessionId;
  final SessionStore _sessionStore;
  final SessionManager _sessionManager;

  AppState(this._sessionStore, this._sessionManager) {
    _loadSessions();
  }

  List<Session> get sessions => List.unmodifiable(_sessions);
  Session? get activeSession => _activeSessionId != null
      ? _sessions.cast<Session?>().firstWhere(
          (s) => s?.id == _activeSessionId,
          orElse: () => null,
        )
      : null;

  Terminal? getTerminal(String sessionId) => _terminals[sessionId];

  Future<void> _loadSessions() async {
    final stored = await _sessionStore.loadAll();
    _sessions.addAll(stored);
    notifyListeners();
  }

  Future<Session> createSession({
    required String repoPath,
    required AgentType agentType,
    required String instructions,
    String branchPrefix = 'agent',
    String? parentBranch,
  }) async {
    final id = const Uuid().v4();
    final number = _sessions.length + 1;
    final branchName = '$branchPrefix/$id';

    final agentSession = await _sessionManager.createSession(
      id: id,
      repoPath: repoPath,
      agentType: agentType,
      instructions: instructions,
      branchPrefix: branchPrefix,
      parentBranch: parentBranch,
    );

    final session = Session(
      id: id,
      number: number,
      name: 'Session #$number',
      repoPath: repoPath,
      worktreePath: agentSession.worktreePath,
      gitBranch: branchName,
      agentType: agentType,
      instructions: instructions,
      status: SessionStatus.running,
    );

    _sessions.add(session);
    _terminals[session.id] = agentSession.terminal;
    await _sessionStore.save(session);

    _activeSessionId = session.id;
    notifyListeners();

    return session;
  }

  void setActiveSession(String sessionId) {
    _activeSessionId = sessionId;
    notifyListeners();
  }

  Future<void> closeSession(String sessionId, {bool cleanupWorktree = true}) async {
    final session = _sessions.cast<Session?>().firstWhere(
      (s) => s?.id == sessionId,
      orElse: () => null,
    );

    if (session == null) return;

    await _sessionManager.terminateSession(sessionId);

    _terminals[sessionId]?.dispose();
    _terminals.remove(sessionId);

    _sessions.removeWhere((s) => s.id == sessionId);
    await _sessionStore.delete(sessionId);

    if (cleanupWorktree) {
      await _sessionManager.cleanupWorktree(
        session.worktreePath,
        session.repoPath,
      );
    }

    if (_activeSessionId == sessionId) {
      _activeSessionId = _sessions.isNotEmpty ? _sessions.first.id : null;
    }

    notifyListeners();
  }
}
```

**Step 2: Commit**

```bash
git add lib/state/app_state.dart
git commit -m "feat: add AppState provider for state management"
```

---

## Task 11: Create Settings State

**Files:**
- Create: `lib/state/settings_state.dart`

**Step 1: Create SettingsState provider**

Create `lib/state/settings_state.dart`:

```dart
import 'package:flutter/material.dart';
import '../models/settings.dart';
import '../services/settings_store.dart';

class SettingsState extends ChangeNotifier {
  final SettingsStore _store;
  Settings _settings;
  bool _loaded = false;

  SettingsState(this._store) : _settings = Settings();

  Settings get settings => _settings;
  bool get loaded => _loaded;

  Future<void> load() async {
    _settings = await _store.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> update(Settings settings) async {
    _settings = settings;
    await _store.save(settings);
    notifyListeners();
  }

  Future<void> updateApp(AppSettings app) async {
    _settings = _settings.copyWith(app: app);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> updateTerminal(TerminalSettings terminal) async {
    _settings = _settings.copyWith(terminal: terminal);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> updateAgents(AgentSettings agents) async {
    _settings = _settings.copyWith(agents: agents);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> reset() async {
    await _store.reset();
    _settings = Settings();
    notifyListeners();
  }
}
```

**Step 2: Commit**

```bash
git add lib/state/settings_state.dart
git commit -m "feat: add SettingsState provider for settings management"
```

---

## Task 12: Create Terminal View

**Files:**
- Create: `lib/ui/terminal/terminal_view.dart`

**Step 1: Create TerminalView widget**

Create `lib/ui/terminal/terminal_view.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:libghostty/libghostty.dart';

class TerminalView extends StatefulWidget {
  final Terminal terminal;
  final void Function(String)? onInput;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final String? fontFamily;
  final double? fontSize;

  const TerminalView({
    required this.terminal,
    this.onInput,
    this.backgroundColor,
    this.foregroundColor,
    this.fontFamily,
    this.fontSize,
    super.key,
  });

  @override
  State<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends State<TerminalView> {
  late final FocusNode _focusNode;
  late final TextEditingController _inputBuffer;
  String _currentLine = '';

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _inputBuffer = TextEditingController();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _inputBuffer.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      widget.onInput?.call('$_currentLine\n');
      _currentLine = '';
    } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_currentLine.isNotEmpty) {
        _currentLine = _currentLine.substring(0, _currentLine.length - 1);
        widget.onInput?.call('\x7f');
      }
    } else if (event.character != null) {
      _currentLine += event.character!;
      widget.onInput?.call(event.character!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: Container(
          color: widget.backgroundColor ?? const Color(0xFF0A0A0A),
          padding: const EdgeInsets.all(8),
          child: SingleChildScrollView(
            child: _buildTerminalContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildTerminalContent() {
    final buffer = StringBuffer();

    for (var row = 0; row < widget.terminal.screen.rows; row++) {
      final line = widget.terminal.screen.lineAt(row);
      buffer.writeln(line.text);
    }

    return SelectableText(
      buffer.toString(),
      style: TextStyle(
        fontFamily: widget.fontFamily ?? 'JetBrains Mono',
        fontSize: widget.fontSize ?? 14,
        color: widget.foregroundColor ?? const Color(0xFFF0F0F0),
        fontFeatures: const [
          FontFeature.tabularFigures(),
          FontFeature.ligatures(),
        ],
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/ui/terminal/terminal_view.dart
git commit -m "feat: add TerminalView widget with libghostty integration"
```

---

## Task 13: Create Session Card Widget

**Files:**
- Create: `lib/ui/session/session_card.dart`

**Step 1: Create SessionCard widget**

Create `lib/ui/session/session_card.dart`:

```dart
import 'package:flutter/material.dart';
import '../../models/session.dart';

class SessionCard extends StatelessWidget {
  final Session session;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const SessionCard({
    required this.session,
    required this.isActive,
    required this.onTap,
    required this.onClose,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive
          ? Theme.of(context).colorScheme.primaryContainer
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _buildStatusIndicator(),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: isActive ? FontWeight.bold : null,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _getAgentLabel(session.agentType),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: onClose,
                tooltip: 'Close session',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    Color color;
    switch (session.status) {
      case SessionStatus.running:
        color = Colors.green;
        break;
      case SessionStatus.starting:
        color = Colors.orange;
        break;
      case SessionStatus.error:
        color = Colors.red;
        break;
      case SessionStatus.idle:
        color = Colors.grey;
        break;
      case SessionStatus.terminated:
        color = Colors.grey;
        break;
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  String _getAgentLabel(AgentType type) {
    switch (type) {
      case AgentType.claude:
        return 'Claude';
      case AgentType.codex:
        return 'Codex';
      case AgentType.opencode:
        return 'OpenCode';
    }
  }
}
```

**Step 2: Commit**

```bash
git add lib/ui/session/session_card.dart
git commit -m "feat: add SessionCard widget for sidebar"
```

---

## Task 14: Create New Session Dialog

**Files:**
- Create: `lib/ui/session/new_session_dialog.dart`

**Step 1: Create NewSessionDialog widget**

Create `lib/ui/session/new_session_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../../models/session.dart';
import '../../services/git_checker.dart';

class NewSessionDialog extends StatefulWidget {
  final void Function({
    required String repoPath,
    required AgentType agentType,
    required String instructions,
  }) onCreate;

  const NewSessionDialog({
    required this.onCreate,
    super.key,
  });

  @override
  State<NewSessionDialog> createState() => _NewSessionDialogState();
}

class _NewSessionDialogState extends State<NewSessionDialog> {
  final _repoController = TextEditingController();
  final _instructionsController = TextEditingController();
  AgentType _selectedAgent = AgentType.claude;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _repoController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _selectRepo() async {
    final directory = await getDirectoryPath();
    if (directory != null) {
      _repoController.text = directory;
      setState(() => _error = null);
    }
  }

  Future<void> _createSession() async {
    final repoPath = _repoController.text.trim();
    final instructions = _instructionsController.text.trim();

    if (repoPath.isEmpty) {
      setState(() => _error = 'Please select a repository');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await GitChecker.verifyRepo(repoPath);
      
      widget.onCreate(
        repoPath: repoPath,
        agentType: _selectedAgent,
        instructions: instructions,
      );
      
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Session'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Repository path
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _repoController,
                    decoration: const InputDecoration(
                      labelText: 'Repository Path',
                      hintText: '/path/to/repo',
                    ),
                    readOnly: true,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.folder_open),
                  onPressed: _selectRepo,
                  tooltip: 'Browse',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Agent selection
            DropdownButtonFormField<AgentType>(
              value: _selectedAgent,
              decoration: const InputDecoration(labelText: 'Coding Agent'),
              items: AgentType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_getAgentLabel(type)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedAgent = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Instructions
            TextField(
              controller: _instructionsController,
              decoration: const InputDecoration(
                labelText: 'Instructions',
                hintText: 'What should the agent do?',
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),

            // Error message
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _createSession,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Start Session'),
        ),
      ],
    );
  }

  String _getAgentLabel(AgentType type) {
    switch (type) {
      case AgentType.claude:
        return 'Claude';
      case AgentType.codex:
        return 'Codex';
      case AgentType.opencode:
        return 'OpenCode';
    }
  }
}
```

**Step 2: Commit**

```bash
git add lib/ui/session/new_session_dialog.dart
git commit -m "feat: add NewSessionDialog for creating sessions"
```

---

## Task 15: Create Sidebar Widget

**Files:**
- Create: `lib/ui/home/sidebar.dart`

**Step 1: Create Sidebar widget**

Create `lib/ui/home/sidebar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../session/session_card.dart';

class Sidebar extends StatelessWidget {
  final VoidCallback onNewSession;
  final VoidCallback onSettings;

  const Sidebar({
    required this.onNewSession,
    required this.onSettings,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final sessions = appState.sessions;

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(
                  'blah',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: onNewSession,
                  tooltip: 'New session',
                ),
              ],
            ),
          ),
          const Divider(),

          // Session list
          Expanded(
            child: sessions.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No sessions\n\nClick + to create'),
                    ),
                  )
                : ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return SessionCard(
                        session: session,
                        isActive: appState.activeSession?.id == session.id,
                        onTap: () => appState.setActiveSession(session.id),
                        onClose: () => appState.closeSession(session.id),
                      );
                    },
                  ),
          ),

          // Footer
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: onSettings,
                  tooltip: 'Settings',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/ui/home/sidebar.dart
git commit -m "feat: add Sidebar widget for session list"
```

---

## Task 16: Create Settings Dialog

**Files:**
- Create: `lib/ui/settings/settings_dialog.dart`
- Create: `lib/ui/settings/app_tab.dart`
- Create: `lib/ui/settings/terminal_tab.dart`

**Step 1: Create SettingsDialog widget**

Create `lib/ui/settings/settings_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import '../../models/settings.dart';

class SettingsDialog extends StatefulWidget {
  final Settings initialSettings;
  final void Function(Settings) onSave;

  const SettingsDialog({
    required this.initialSettings,
    required this.onSave,
    super.key,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AppSettings _appSettings;
  late TerminalSettings _terminalSettings;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _appSettings = widget.initialSettings.app;
    _terminalSettings = widget.initialSettings.terminal;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave(Settings(
      app: _appSettings,
      terminal: _terminalSettings,
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'General'),
                Tab(text: 'Terminal'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _AppSettingsTab(
                    settings: _appSettings,
                    onChanged: (settings) => setState(() => _appSettings = settings),
                  ),
                  _TerminalSettingsTab(
                    settings: _terminalSettings,
                    onChanged: (settings) =>
                        setState(() => _terminalSettings = settings),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _AppSettingsTab extends StatelessWidget {
  final AppSettings settings;
  final void Function(AppSettings) onChanged;

  const _AppSettingsTab({
    required this.settings,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Branch Prefix',
              helperText: 'Prefix for agent worktree branches',
            ),
            controller: TextEditingController(text: settings.branchPrefix),
            onChanged: (value) =>
                onChanged(settings.copyWith(branchPrefix: value)),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Auto-cleanup Worktrees'),
            subtitle: const Text('Delete worktrees when sessions close'),
            value: settings.autoCleanupWorktrees,
            onChanged: (value) =>
                onChanged(settings.copyWith(autoCleanupWorktrees: value)),
          ),
          SwitchListTile(
            title: const Text('Confirm on Close'),
            subtitle: const Text('Ask before closing session'),
            value: settings.confirmOnClose,
            onChanged: (value) =>
                onChanged(settings.copyWith(confirmOnClose: value)),
          ),
        ],
      ),
    );
  }
}

class _TerminalSettingsTab extends StatelessWidget {
  final TerminalSettings settings;
  final void Function(TerminalSettings) onChanged;

  const _TerminalSettingsTab({
    required this.settings,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: settings.fontFamily,
            decoration: const InputDecoration(labelText: 'Font Family'),
            items: ['JetBrains Mono', 'Fira Code', 'Hack', 'Source Code Pro']
                .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                onChanged(settings.copyWith(fontFamily: value));
              }
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(labelText: 'Font Size'),
                  keyboardType: TextInputType.number,
                  controller:
                      TextEditingController(text: settings.fontSize.toString()),
                  onChanged: (value) {
                    final size = double.tryParse(value) ?? 14;
                    onChanged(settings.copyWith(fontSize: size));
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: settings.themeName,
                  decoration: const InputDecoration(labelText: 'Theme'),
                  items: ['dark', 'light', 'dracula']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      onChanged(settings.copyWith(themeName: value));
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Enable Ligatures'),
            subtitle: const Text('Requires font with ligature support'),
            value: settings.ligaturesEnabled,
            onChanged: (value) =>
                onChanged(settings.copyWith(ligaturesEnabled: value)),
          ),
          SwitchListTile(
            title: const Text('Cursor Blink'),
            value: settings.cursorBlink,
            onChanged: (value) =>
                onChanged(settings.copyWith(cursorBlink: value)),
          ),
        ],
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/ui/settings/settings_dialog.dart
git commit -m "feat: add SettingsDialog for app configuration"
```

---

## Task 17: Create Home Screen

**Files:**
- Create: `lib/ui/home/home_screen.dart`

**Step 1: Create HomeScreen widget**

Create `lib/ui/home/home_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../session/new_session_dialog.dart';
import '../settings/settings_dialog.dart';
import '../terminal/terminal_view.dart';
import 'sidebar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final activeSession = appState.activeSession;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          SizedBox(
            width: 250,
            child: Sidebar(
              onNewSession: () => _showNewSessionDialog(context),
              onSettings: () => _showSettingsDialog(context),
            ),
          ),

          // Main terminal area
          Expanded(
            child: activeSession != null
                ? TerminalPane(sessionId: activeSession.id)
                : const EmptyState(),
          ),
        ],
      ),
    );
  }

  void _showNewSessionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => NewSessionDialog(
        onCreate: ({
          required String repoPath,
          required agentType,
          required String instructions,
        }) {
          context.read<AppState>().createSession(
                repoPath: repoPath,
                agentType: agentType,
                instructions: instructions,
              );
        },
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    final settings = context.read<AppState>().settings;
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(
        initialSettings: settings,
        onSave: (newSettings) {
          // TODO: Wire up settings save
        },
      ),
    );
  }
}

class TerminalPane extends StatelessWidget {
  final String sessionId;

  const TerminalPane({required this.sessionId, super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final session = appState.sessions.cast<Session?>().firstWhere(
          (s) => s?.id == sessionId,
          orElse: () => null,
        );
    final terminal = appState.getTerminal(sessionId);

    if (session == null || terminal == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Header bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Row(
            children: [
              Icon(_getAgentIcon(session.agentType), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  session.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _StatusBadge(status: session.status),
            ],
          ),
        ),

        // Terminal
        Expanded(
          child: TerminalView(
            terminal: terminal,
            onInput: (input) {
              // TODO: Wire up input to session manager
            },
          ),
        ),
      ],
    );
  }

  IconData _getAgentIcon(AgentType type) {
    switch (type) {
      case AgentType.claude:
        return Icons.smart_toy;
      case AgentType.codex:
        return Icons.code;
      case AgentType.opencode:
        return Icons.terminal;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final SessionStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case SessionStatus.running:
        color = Colors.green;
        label = 'Running';
        break;
      case SessionStatus.starting:
        color = Colors.orange;
        label = 'Starting';
        break;
      case SessionStatus.idle:
        color = Colors.grey;
        label = 'Idle';
        break;
      case SessionStatus.error:
        color = Colors.red;
        label = 'Error';
        break;
      case SessionStatus.terminated:
        color = Colors.grey;
        label = 'Terminated';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.terminal,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No active sessions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Click + in the sidebar to create a new session',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
```

**Note:** This file has an import for `Session` and `AgentType` that needs to reference `../../models/session.dart`. Add this import.

**Step 2: Fix imports and commit**

```bash
git add lib/ui/home/home_screen.dart
git commit -m "feat: add HomeScreen main layout"
```

---

## Task 18: Create App Entry Point

**Files:**
- Modify: `lib/main.dart`
- Create: `lib/app.dart`

**Step 1: Create App widget**

Create `lib/app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/app_state.dart';
import 'state/settings_state.dart';
import 'ui/home/home_screen.dart';

class BlahApp extends StatelessWidget {
  const BlahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'blah',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
```

**Step 2: Update main.dart**

Replace `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/session_store.dart';
import 'services/settings_store.dart';
import 'services/session_manager.dart';
import 'state/app_state.dart';
import 'state/settings_state.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sessionStore = SessionStore();
  final settingsStore = SettingsStore();
  final sessionManager = SessionManager();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppState(sessionStore, sessionManager),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsState(settingsStore)..load(),
        ),
      ],
      child: const BlahApp(),
    ),
  );
}
```

**Step 3: Commit**

```bash
git add lib/main.dart lib/app.dart
git commit -m "feat: wire up app entry point with providers"
```

---

## Task 19: Add Missing Model Import

**Files:**
- Modify: `lib/ui/home/home_screen.dart`

**Step 1: Add import**

Add import at top of `lib/ui/home/home_screen.dart`:

```dart
import '../../models/session.dart';
```

**Step 2: Commit**

```bash
git add lib/ui/home/home_screen.dart
git commit -m "fix: add missing Session import to HomeScreen"
```

---

## Task 20: Add Settings to AppState

**Files:**
- Modify: `lib/state/app_state.dart`

**Step 1: Add settings reference**

Add to AppState in `lib/state/app_state.dart`:

```dart
class AppState extends ChangeNotifier {
  // ... existing code ...

  Settings get settings => _settingsState.settings;
  final SettingsState _settingsState;

  AppState(this._sessionStore, this._sessionManager, this._settingsState) {
    _loadSessions();
  }

  // ... rest of code ...
}
```

**Step 2: Update main.dart**

Update Providers in `lib/main.dart`:

```dart
final sessionStore = SessionStore();
final settingsStore = SettingsStore();
final sessionManager = SessionManager();
final settingsState = SettingsState(settingsStore)..load();

runApp(
  MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => AppState(sessionStore, sessionManager, settingsState),
      ),
      ChangeNotifierProvider.value(value: settingsState),
    ],
    child: const BlahApp(),
  ),
);
```

**Step 3: Commit**

```bash
git add lib/state/app_state.dart lib/main.dart
git commit -m "fix: wire up SettingsState to AppState"
```

---

## Task 21: Test Run

**Step 1: Get dependencies**

Run: `flutter pub get`

Expected: Dependencies downloaded successfully

**Step 2: Run on Linux**

Run: `flutter run -d linux`

Expected: App launches with empty state

**Step 3: Test flow**

1. Click `+` in sidebar
2. Select repository
3. Choose agent
4. Enter instructions
5. Click "Start Session"

Expected: Session appears in sidebar, terminal shows agent output

---

## Task 22: Create README

**Files:**
- Modify: `README.md`

**Step 1: Add README content**

Replace `README.md`:

```markdown
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
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README"
```

---

## Summary

21 tasks implementing blah:

1. Initialize Flutter project
2. Create Error models
3. Create Session model
4. Create Settings models
5. Create SessionStore
6. Create SettingsStore
7. Create GitChecker
8. Create AgentChecker
9. Create SessionManager
10. Create AppState
11. Create SettingsState
12. Create TerminalView
13. Create SessionCard
14. Create NewSessionDialog
15. Create Sidebar
16. Create SettingsDialog
17. Create HomeScreen
18. Create App entry
19. Add missing imports
20. Wire up Settings
21. Test run
22. Create README

Each task follows TDD: write code, verify it works, commit.