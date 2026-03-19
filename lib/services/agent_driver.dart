import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/branding.dart';
import '../errors/errors.dart';
import '../models/chat.dart';
import '../models/session.dart';
import 'git_checker.dart';
import 'ops/command_runner.dart';
import 'ops/worktree_ops.dart';

String _shellQuote(String value) {
  if (value.isEmpty) return "''";
  final safe = RegExp(r'^[a-zA-Z0-9_./:@=-]+?$');
  if (safe.hasMatch(value)) return value;
  return "'${value.replaceAll("'", "'\\''")}'";
}

String formatCommandLine(String executable, List<String> args) {
  final parts = [executable, ...args].map(_shellQuote).toList();
  return parts.join(' ');
}

List<String> buildOpenCodeRunArgs({
  required String worktreePath,
  required String message,
  required bool hasExistingSession,
}) {
  return [
    'run',
    '--format',
    'json',
    '--dir',
    worktreePath,
    if (hasExistingSession) '--continue',
    message,
  ];
}

List<String> buildCodexExecArgs({
  required String worktreePath,
  required String message,
}) {
  return [
    'exec',
    '--json',
    '--full-auto',
    '-C',
    worktreePath,
    message,
  ];
}

String? extractOpenCodeText(Map<String, dynamic> data) {
  final part = data['part'];
  if (part is Map && part['text'] is String) {
    return part['text'] as String;
  }
  if (data['text'] is String) {
    return data['text'] as String;
  }
  return null;
}

String? extractCodexText(Map<String, dynamic> data) {
  final item = data['item'];
  if (item is Map &&
      item['type'] == 'agent_message' &&
      item['text'] is String) {
    return item['text'] as String;
  }
  if (data['text'] is String) {
    return data['text'] as String;
  }
  return null;
}

/// Parsed event from agent JSON output
class AgentEvent {
  final String type;
  final Map<String, dynamic> data;

  const AgentEvent(this.type, this.data);
}

/// Callback types for agent events
typedef OnMessageCallback = void Function(ChatMessage message);
typedef OnMessageUpdateCallback = void Function(
    String messageId, ChatMessage updated);
typedef OnToolUseCallback = void Function(String messageId, ToolUse toolUse);
typedef OnErrorCallback = void Function(String error);
typedef OnExitCallback = void Function(int exitCode);

/// Drives a headless agent process and streams chat messages
class AgentDriver {
  final String sessionId;
  final AgentType agentType;
  final String worktreePath;

  Process? _process;
  final _messageController = StreamController<ChatMessage>.broadcast();
  final _eventController = StreamController<AgentEvent>.broadcast();

  String _currentAssistantMessageId = '';
  StringBuffer _currentAssistantContent = StringBuffer();
  List<ToolUse> _currentToolUses = [];
  bool _isStreaming = false;
  bool _isDisposed = false;
  bool _opencodeHasSession = false;

  AgentDriver({
    required this.sessionId,
    required this.agentType,
    required this.worktreePath,
  });

  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<AgentEvent> get eventStream => _eventController.stream;
  bool get isRunning => _process != null;

  String debugCommandForMessage(String content) {
    if (agentType == AgentType.opencode) {
      final args = buildOpenCodeRunArgs(
        worktreePath: worktreePath,
        message: content,
        hasExistingSession: _opencodeHasSession,
      );
      return formatCommandLine('opencode', args);
    }

    if (agentType == AgentType.codex) {
      final args = buildCodexExecArgs(
        worktreePath: worktreePath,
        message: content,
      );
      return formatCommandLine('codex', args);
    }

    final (executable, args) = _getAgentCommand();
    return formatCommandLine(executable, args);
  }

  /// Start the agent process in headless JSON mode
  Future<void> start() async {
    if (agentType == AgentType.opencode || agentType == AgentType.codex) {
      // OpenCode and Codex run modes are one-shot per message.
      return;
    }

    if (_process != null) {
      throw AppError(
        ErrorCode.processSpawnFailed,
        message: 'Agent already running',
      );
    }

    final (executable, args) = _getAgentCommand();

    try {
      _process = await Process.start(
        executable,
        args,
        workingDirectory: worktreePath,
        environment: {
          ...Platform.environment,
          'TERM': 'xterm-256color',
          'COLORTERM': 'truecolor',
          'NO_COLOR': '1', // Disable color codes in JSON output
        },
      );

      // Listen to stdout for JSON events
      _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleOutputLine, onError: _handleError);

      // Listen to stderr for errors
      _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleStderrLine);

      // Handle process exit
      _process!.exitCode.then(_handleExit);
    } catch (e) {
      throw AppError(
        ErrorCode.processSpawnFailed,
        message: 'Failed to start ${agentType.name}',
        details: e.toString(),
        recoveryHint: 'Ensure ${agentType.name} is installed and in PATH',
      );
    }
  }

  /// Get the command and args for running the agent in headless JSON mode
  (String, List<String>) _getAgentCommand() {
    switch (agentType) {
      case AgentType.claude:
        return (
          'claude',
          [
            '-p', // Print mode (non-interactive)
            '--verbose', // Required for stream-json
            '--output-format', 'stream-json',
            '--input-format', 'stream-json',
            '--session-id', sessionId,
          ]
        );
      case AgentType.codex:
        return (
          'codex',
          [
            'exec',
            '--json', // JSONL output
            '--full-auto', // Non-interactive
            '-C', worktreePath,
          ]
        );
      case AgentType.opencode:
        return (
          'opencode',
          [
            'run',
            '--format',
            'json',
            '--dir',
            worktreePath,
          ]
        );
    }
  }

  /// Send a message to the agent
  Future<void> sendMessage(String content) async {
    // Create user message
    final userMessage = ChatMessage(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      role: MessageRole.user,
      content: content,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
    );
    _messageController.add(userMessage);

    // Prepare for assistant response
    _currentAssistantMessageId =
        'assistant-${DateTime.now().millisecondsSinceEpoch}';
    _currentAssistantContent = StringBuffer();
    _currentToolUses = [];
    _isStreaming = true;

    if (agentType == AgentType.opencode) {
      await _sendOpenCodeMessage(content);
      return;
    }

    if (agentType == AgentType.codex) {
      await _sendCodexMessage(content);
      return;
    }

    if (_process == null) {
      throw AppError(
        ErrorCode.processSpawnFailed,
        message: 'Agent not running',
      );
    }

    // Send to agent based on format
    final inputJson = _formatInputMessage(content);
    _process!.stdin.writeln(inputJson);
  }

  Future<void> _sendOpenCodeMessage(String content) async {
    final args = buildOpenCodeRunArgs(
      worktreePath: worktreePath,
      message: content,
      hasExistingSession: _opencodeHasSession,
    );

    try {
      final process = await Process.start(
        'opencode',
        args,
        workingDirectory: worktreePath,
        environment: {
          ...Platform.environment,
          'TERM': 'xterm-256color',
          'COLORTERM': 'truecolor',
          'NO_COLOR': '1',
        },
      );

      _process = process;

      // One-shot commands provide prompt via args; close stdin so the CLI
      // does not wait for additional piped input.
      unawaited(process.stdin.close());

      final stdoutDone = Completer<void>();
      final stderrDone = Completer<void>();

      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        _handleOutputLine,
        onError: _handleError,
        onDone: () {
          if (!stdoutDone.isCompleted) stdoutDone.complete();
        },
      );

      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        _handleStderrLine,
        onDone: () {
          if (!stderrDone.isCompleted) stderrDone.complete();
        },
      );

      final exitCode = await process.exitCode;

      // Ensure all output has been consumed before finalizing message state.
      await Future.wait([stdoutDone.future, stderrDone.future]);

      _handleExit(exitCode);

      if (exitCode == 0) {
        _opencodeHasSession = true;
      }
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  Future<void> _sendCodexMessage(String content) async {
    final args = buildCodexExecArgs(
      worktreePath: worktreePath,
      message: content,
    );

    try {
      final process = await Process.start(
        'codex',
        args,
        workingDirectory: worktreePath,
        environment: {
          ...Platform.environment,
          'TERM': 'xterm-256color',
          'COLORTERM': 'truecolor',
          'NO_COLOR': '1',
        },
      );

      _process = process;

      // One-shot commands provide prompt via args; close stdin to avoid
      // waiting on further input.
      unawaited(process.stdin.close());

      final stdoutDone = Completer<void>();
      final stderrDone = Completer<void>();

      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        _handleOutputLine,
        onError: _handleError,
        onDone: () {
          if (!stdoutDone.isCompleted) stdoutDone.complete();
        },
      );

      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        _handleStderrLine,
        onDone: () {
          if (!stderrDone.isCompleted) stderrDone.complete();
        },
      );

      final exitCode = await process.exitCode;

      // Ensure all output has been consumed before finalizing message state.
      await Future.wait([stdoutDone.future, stderrDone.future]);

      _handleExit(exitCode);
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  /// Format input message for the specific agent
  String _formatInputMessage(String content) {
    switch (agentType) {
      case AgentType.claude:
        // Claude stream-json input format
        return jsonEncode({
          'type': 'user',
          'message': {'role': 'user', 'content': content}
        });
      case AgentType.codex:
        // Codex reads prompt from stdin directly
        return content;
      case AgentType.opencode:
        // OpenCode takes message as argument, not stdin
        // For ongoing conversation, we may need different approach
        return content;
    }
  }

  /// Handle a line of JSON output from the agent
  void _handleOutputLine(String line) {
    if (line.trim().isEmpty) return;

    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      final event = _parseAgentEvent(json);
      _eventController.add(event);
      _processEvent(event);
    } catch (e) {
      // Not valid JSON, might be plain text output
      _handlePlainTextOutput(line);
    }
  }

  /// Parse agent-specific JSON into normalized AgentEvent
  AgentEvent _parseAgentEvent(Map<String, dynamic> json) {
    switch (agentType) {
      case AgentType.claude:
        return _parseClaudeEvent(json);
      case AgentType.codex:
        return _parseCodexEvent(json);
      case AgentType.opencode:
        return _parseOpenCodeEvent(json);
    }
  }

  AgentEvent _parseClaudeEvent(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'unknown';
    return AgentEvent(type, json);
  }

  AgentEvent _parseCodexEvent(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'unknown';
    return AgentEvent(type, json);
  }

  AgentEvent _parseOpenCodeEvent(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'unknown';
    return AgentEvent(type, json);
  }

  /// Process a normalized event and update chat state
  void _processEvent(AgentEvent event) {
    switch (event.type) {
      // Claude events
      case 'assistant':
      case 'content_block_delta':
      case 'message_delta':
        _handleTextEvent(event);
        break;
      case 'tool_use':
        _handleToolUseEvent(event);
        break;
      case 'tool_result':
        _handleToolResultEvent(event);
        break;
      case 'message_stop':
      case 'end':
        _finalizeCurrentMessage();
        break;

      // Codex events
      case 'message':
      case 'item.completed':
        _handleCodexMessageEvent(event);
        break;
      case 'function_call':
        _handleToolUseEvent(event);
        break;
      case 'turn.completed':
        _finalizeCurrentMessage();
        break;

      // OpenCode events
      case 'text':
        _handleTextEvent(event);
        break;
      case 'step_finish':
        _finalizeCurrentMessage();
        break;
      case 'tool':
        _handleToolUseEvent(event);
        break;

      default:
        // Unknown event type, log for debugging
        break;
    }
  }

  void _handleTextEvent(AgentEvent event) {
    String? text;

    // Extract text based on event structure
    if (event.data.containsKey('message')) {
      final message = event.data['message'];
      if (message is Map && message.containsKey('content')) {
        final content = message['content'];
        if (content is String) {
          text = content;
        } else if (content is List && content.isNotEmpty) {
          final first = content.first;
          if (first is Map && first['type'] == 'text') {
            text = first['text'] as String?;
          }
        }
      }
    } else if (event.data.containsKey('delta')) {
      final delta = event.data['delta'];
      if (delta is Map && delta.containsKey('text')) {
        text = delta['text'] as String?;
      }
    } else if (event.data.containsKey('content')) {
      text = event.data['content'] as String?;
    } else if (event.data.containsKey('text')) {
      text = event.data['text'] as String?;
    } else {
      text = extractOpenCodeText(event.data);
    }

    if (text != null && text.isNotEmpty) {
      _currentAssistantContent.write(text);
      _emitCurrentMessage(MessageStatus.streaming);
    }
  }

  void _handleCodexMessageEvent(AgentEvent event) {
    final text = extractCodexText(event.data);

    if (text != null && text.isNotEmpty) {
      _currentAssistantContent.write(text);
      _emitCurrentMessage(MessageStatus.streaming);
    }
  }

  void _handleToolUseEvent(AgentEvent event) {
    final toolUse = ToolUse(
      id: event.data['id'] as String? ??
          'tool-${DateTime.now().millisecondsSinceEpoch}',
      name: event.data['name'] as String? ??
          event.data['function'] as String? ??
          'unknown',
      input: (event.data['input'] as Map<String, dynamic>?) ??
          (event.data['arguments'] as Map<String, dynamic>?) ??
          {},
    );
    _currentToolUses.add(toolUse);
    _emitCurrentMessage(MessageStatus.streaming);
  }

  void _handleToolResultEvent(AgentEvent event) {
    final toolId = event.data['tool_use_id'] as String?;
    final output = event.data['content'] as String? ??
        event.data['output'] as String? ??
        '';

    if (toolId != null) {
      final index = _currentToolUses.indexWhere((t) => t.id == toolId);
      if (index >= 0) {
        _currentToolUses[index] = _currentToolUses[index].copyWith(
          output: output,
          isComplete: true,
        );
        _emitCurrentMessage(MessageStatus.streaming);
      }
    }
  }

  void _emitCurrentMessage(MessageStatus status) {
    if (_currentAssistantMessageId.isEmpty) return;

    final message = ChatMessage(
      id: _currentAssistantMessageId,
      role: MessageRole.assistant,
      content: _currentAssistantContent.toString(),
      timestamp: DateTime.now(),
      status: status,
      toolUses: List.from(_currentToolUses),
    );
    _messageController.add(message);
  }

  void _finalizeCurrentMessage() {
    if (_isStreaming) {
      _emitCurrentMessage(MessageStatus.complete);
      _isStreaming = false;
      _currentAssistantMessageId = '';
    }
  }

  void _handlePlainTextOutput(String line) {
    // For agents that output plain text mixed with JSON
    if (_isStreaming) {
      _currentAssistantContent.writeln(line);
      _emitCurrentMessage(MessageStatus.streaming);
    }
  }

  void _handleStderrLine(String line) {
    // Log stderr but don't treat as error unless it looks like one
    if (line.toLowerCase().contains('error') ||
        line.toLowerCase().contains('fatal')) {
      final errorMessage = ChatMessage(
        id: 'error-${DateTime.now().millisecondsSinceEpoch}',
        role: MessageRole.system,
        content: line,
        timestamp: DateTime.now(),
        status: MessageStatus.error,
        error: line,
      );
      _messageController.add(errorMessage);
    }
  }

  void _handleError(Object error) {
    final errorMessage = ChatMessage(
      id: 'error-${DateTime.now().millisecondsSinceEpoch}',
      role: MessageRole.system,
      content: 'Agent error: $error',
      timestamp: DateTime.now(),
      status: MessageStatus.error,
      error: error.toString(),
    );
    _messageController.add(errorMessage);
  }

  void _handleExit(int exitCode) {
    _finalizeCurrentMessage();
    _process = null;

    if (exitCode != 0) {
      final exitMessage = ChatMessage(
        id: 'exit-${DateTime.now().millisecondsSinceEpoch}',
        role: MessageRole.system,
        content: 'Agent exited with code $exitCode',
        timestamp: DateTime.now(),
        status: MessageStatus.complete,
      );
      _messageController.add(exitMessage);
    }
  }

  /// Stop the agent process
  Future<void> stop() async {
    final process = _process;
    _process = null;

    if (process != null) {
      process.kill(ProcessSignal.sigterm);
      try {
        await process.exitCode.timeout(const Duration(seconds: 2));
      } catch (_) {
        process.kill(ProcessSignal.sigkill);
      }
    }

    _finalizeCurrentMessage();
  }

  /// Dispose resources
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    _process?.kill(ProcessSignal.sigterm);
    _process = null;

    if (!_messageController.isClosed) {
      _messageController.close();
    }
    if (!_eventController.isClosed) {
      _eventController.close();
    }
  }
}

/// Manages multiple agent drivers for different sessions
class AgentDriverManager {
  final Map<String, AgentDriver> _drivers = {};
  final WorktreeOps _worktreeOps;
  final Future<void> Function(String repoPath) _verifyRepo;
  final Future<String> Function(String repoPath) _getCurrentBranch;
  final AgentDriver Function({
    required String sessionId,
    required AgentType agentType,
    required String worktreePath,
  }) _driverFactory;

  AgentDriverManager({
    CommandRunner? commandRunner,
    WorktreeOps? worktreeOps,
    Future<void> Function(String repoPath)? verifyRepo,
    Future<String> Function(String repoPath)? getCurrentBranch,
    AgentDriver Function({
      required String sessionId,
      required AgentType agentType,
      required String worktreePath,
    })? driverFactory,
  })  : _worktreeOps =
            worktreeOps ?? WorktreeOps(commandRunner ?? CommandRunner()),
        _verifyRepo = verifyRepo ?? GitChecker.verifyRepo,
        _getCurrentBranch = getCurrentBranch ?? GitChecker.getCurrentBranch,
        _driverFactory = driverFactory ??
            (({
              required String sessionId,
              required AgentType agentType,
              required String worktreePath,
            }) =>
                AgentDriver(
                  sessionId: sessionId,
                  agentType: agentType,
                  worktreePath: worktreePath,
                ));

  /// Create and start a new agent driver
  Future<AgentDriver> createDriver({
    required String sessionId,
    required AgentType agentType,
    required String repoPath,
    String? branchPrefix,
    String? parentBranch,
  }) async {
    // Verify repo
    await _verifyRepo(repoPath);

    // Create worktree
    final worktreePath = await _createWorktree(
      repoPath: repoPath,
      sessionId: sessionId,
      branchPrefix: branchPrefix,
      parentBranch: parentBranch,
    );

    // Create driver
    final driver = _driverFactory(
      sessionId: sessionId,
      agentType: agentType,
      worktreePath: worktreePath,
    );

    // Start it and cleanup worktree if start fails.
    try {
      await driver.start();
    } catch (error) {
      try {
        await _worktreeOps.remove(
          repoPath: repoPath,
          worktreePath: worktreePath,
        );
      } catch (_) {
        // Best-effort cleanup; preserve original start failure.
      }
      rethrow;
    }

    _drivers[sessionId] = driver;
    return driver;
  }

  Future<String> _createWorktree({
    required String repoPath,
    required String sessionId,
    String? branchPrefix,
    String? parentBranch,
  }) async {
    final worktreesDir = Branding.worktreesPath(repoPath);
    final prefix = branchPrefix ?? Branding.defaultBranchPrefix;
    final branchName = '$prefix/$sessionId';
    final worktreePath = '$worktreesDir/$branchName';

    await Directory(worktreesDir).create(recursive: true);

    parentBranch ??= await _getCurrentBranch(repoPath);

    await _worktreeOps.create(
      repoPath: repoPath,
      branchName: branchName,
      worktreePath: worktreePath,
      parentBranch: parentBranch,
    );

    return worktreePath;
  }

  AgentDriver? getDriver(String sessionId) => _drivers[sessionId];

  Future<void> stopDriver(String sessionId) async {
    final driver = _drivers.remove(sessionId);
    await driver?.stop();
  }

  Future<void> stopAll() async {
    for (final driver in _drivers.values) {
      await driver.stop();
    }
    _drivers.clear();
  }
}
