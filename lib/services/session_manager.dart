import 'dart:async';
import 'dart:io';
import 'package:xterm/xterm.dart';
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
    await GitChecker.verifyRepo(repoPath);

    final worktreePath = await _createWorktree(
      repoPath: repoPath,
      sessionBranch: '$branchPrefix/$id',
      parentBranch: parentBranch,
    );

    final process = await _spawnAgent(
      agentType: agentType,
      worktreePath: worktreePath,
      sessionId: id,
    );

    final terminal = Terminal();

    _wireProcessIO(id, process, terminal);

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
      terminal.write(String.fromCharCodes(data));
      onMessage?.call({
        'type': 'output',
        'sessionId': sessionId,
        'data': data,
      });
    });

    process.stderr.listen((data) {
      terminal.write(String.fromCharCodes(data));
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
      ['worktree', 'add', '-b', sessionBranch, worktreePath, parentBranch],
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
