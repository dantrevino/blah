import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart';
import '../config/branding.dart';
import '../errors/errors.dart';
import '../models/session.dart';
import 'git_checker.dart';

class AgentSession {
  final String id;
  final Pty pty;
  final Terminal terminal;
  final String worktreePath;
  final AgentType agentType;
  DateTime createdAt;

  AgentSession({
    required this.id,
    required this.pty,
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
    int rows = 24,
    int columns = 80,
  }) async {
    await GitChecker.verifyRepo(repoPath);

    final worktreePath = await _createWorktree(
      repoPath: repoPath,
      sessionBranch: '$branchPrefix/$id',
      parentBranch: parentBranch,
    );

    final pty = _spawnAgent(
      agentType: agentType,
      worktreePath: worktreePath,
      sessionId: id,
      rows: rows,
      columns: columns,
    );

    final terminal = Terminal();

    _wirePtyIO(id, pty, terminal);

    // Send initial instructions after a short delay to let the agent start
    if (instructions.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () {
        pty.write(const Utf8Encoder().convert('$instructions\n'));
      });
    }

    final session = AgentSession(
      id: id,
      pty: pty,
      terminal: terminal,
      worktreePath: worktreePath,
      agentType: agentType,
    );

    _sessions[id] = session;
    return session;
  }

  void _wirePtyIO(
    String sessionId,
    Pty pty,
    Terminal terminal,
  ) {
    // PTY output -> Terminal display
    pty.output.listen((data) {
      terminal.write(utf8.decode(data));
      onMessage?.call({
        'type': 'output',
        'sessionId': sessionId,
        'data': data,
      });
    });

    // PTY exit
    pty.exitCode.then((code) {
      onMessage?.call({
        'type': 'exit',
        'sessionId': sessionId,
        'code': code,
      });
      _sessions.remove(sessionId);
    });
  }

  Pty _spawnAgent({
    required AgentType agentType,
    required String worktreePath,
    required String sessionId,
    required int rows,
    required int columns,
  }) {
    // Each agent has different CLI invocation:
    // - Claude: claude --session-id <uuid> (works from cwd)
    // - Codex: codex (no session flag, uses cwd)
    // - OpenCode: opencode [project] (project path as positional arg)
    final (executable, args) = switch (agentType) {
      AgentType.claude => ('claude', ['--session-id', sessionId]),
      AgentType.codex => ('codex', <String>[]),
      AgentType.opencode => ('opencode', [worktreePath]),
    };

    try {
      return Pty.start(
        executable,
        arguments: args,
        workingDirectory: worktreePath,
        environment: {
          ...Platform.environment,
          'TERM': 'xterm-256color',
          'COLORTERM': 'truecolor',
        },
        rows: rows,
        columns: columns,
      );
    } catch (e) {
      throw AppError(
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
    final worktreesDir = Branding.worktreesPath(repoPath);
    final worktreePath = '$worktreesDir/$sessionBranch';

    await Directory(worktreesDir).create(recursive: true);

    parentBranch ??= await GitChecker.getCurrentBranch(repoPath);

    final result = await Process.run(
      'git',
      ['worktree', 'add', '-b', sessionBranch, worktreePath, parentBranch],
      workingDirectory: repoPath,
    );

    if (result.exitCode != 0) {
      throw AppError(
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

    session.pty.kill();
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
      session.pty.write(const Utf8Encoder().convert(input));
    }
  }

  void resizeTerminal(String sessionId, int rows, int columns) {
    final session = _sessions[sessionId];
    if (session != null) {
      session.pty.resize(rows, columns);
    }
  }

  AgentSession? getSession(String sessionId) => _sessions[sessionId];
}
