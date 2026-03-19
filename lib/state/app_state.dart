import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../ops/models/operation_record.dart';
import '../ops/in_memory_ops_logger.dart';
import '../ops/ops_coordinator.dart';
import '../errors/errors.dart';
import '../config/branding.dart';
import '../models/chat.dart';
import '../models/git_change.dart';
import '../models/session.dart';
import '../models/settings.dart';
import '../services/agent_driver.dart';
import '../services/chat_store.dart';
import '../services/git_status_service.dart';
import '../services/ops/git_watcher.dart';
import '../services/session_store.dart';
import 'settings_state.dart';

class AppState extends ChangeNotifier {
  final List<Session> _sessions = [];
  final Map<String, AgentDriver> _drivers = {};
  final Map<String, ChatSession> _chatSessions = {};
  final Map<String, GitChangesSummary> _gitChanges = {};
  final Map<String, StreamSubscription<ChatMessage>> _messageSubscriptions = {};
  final Map<String, StreamSubscription<GitChangesSummary>>
      _gitWatchSubscriptions = {};
  final Set<String> _terminalOpenSessions = {};

  String? _activeSessionId;
  final SessionStore _sessionStore;
  final ChatStore _chatStore;
  final AgentDriverManager _driverManager;
  final OpsCoordinator _opsCoordinator;
  final InMemoryOpsLogger? _opsLogger;
  final SettingsState _settingsState;
  StreamSubscription? _opsEventsSubscription;

  AppState(
    this._sessionStore,
    this._chatStore,
    this._driverManager,
    this._opsCoordinator,
    this._opsLogger,
    this._settingsState,
  ) {
    _subscribeOpsEvents();
    _loadSessions();
  }

  void _subscribeOpsEvents() {
    _opsEventsSubscription = _opsLogger?.events.listen((operation) {
      if (operation.status != OperationStatus.failed) return;
      if (!settings.app.debugMode) return;
      _appendSystemMessage(
        operation.sessionId,
        'ops failed [${operation.kind.name}] id=${operation.id} ${operation.error ?? 'unknown error'}',
      );
    });
  }

  Settings get settings => _settingsState.settings;

  Future<void> updateSettings(Settings settings) async {
    await _settingsState.update(settings);
    notifyListeners();
  }

  List<Session> get sessions => List.unmodifiable(_sessions);

  Session? get activeSession => _activeSessionId != null
      ? _sessions.cast<Session?>().firstWhere(
            (s) => s?.id == _activeSessionId,
            orElse: () => null,
          )
      : null;

  ChatSession? getChatSession(String sessionId) => _chatSessions[sessionId];

  bool isTerminalOpen(String sessionId) =>
      _terminalOpenSessions.contains(sessionId);

  void toggleTerminal(String sessionId) {
    if (_terminalOpenSessions.contains(sessionId)) {
      _terminalOpenSessions.remove(sessionId);
    } else {
      _terminalOpenSessions.add(sessionId);
    }
    notifyListeners();
  }

  void closeTerminal(String sessionId) {
    _terminalOpenSessions.remove(sessionId);
    notifyListeners();
  }

  AgentDriver? getDriver(String sessionId) => _drivers[sessionId];

  GitChangesSummary getGitChanges(String sessionId) =>
      _gitChanges[sessionId] ?? GitChangesSummary.empty;

  Future<void> _loadSessions() async {
    final stored = await _sessionStore.loadAll();
    _sessions.addAll(stored);

    // Load chat history for all sessions
    final sessionIds = stored.map((s) => s.id).toList();
    final loadedChats = await _chatStore.loadAll(sessionIds);

    // Initialize chat sessions (use loaded or create empty)
    for (final session in stored) {
      _chatSessions[session.id] =
          loadedChats[session.id] ?? ChatSession(id: session.id);
      _startGitWatcher(session.id, session.worktreePath);
    }

    notifyListeners();
  }

  Future<Session> createSession({
    required String name,
    required String repoPath,
    required AgentType agentType,
    String? branchPrefix,
    String? parentBranch,
  }) async {
    final id = const Uuid().v4();
    final number = _sessions.length + 1;
    final prefix = branchPrefix ?? Branding.defaultBranchPrefix;
    final branchName = '$prefix/$id';

    final createResult = await _opsCoordinator.createSessionFlow<AgentDriver>(
      sessionId: id,
      execute: () {
        return _driverManager.createDriver(
          sessionId: id,
          agentType: agentType,
          repoPath: repoPath,
          branchPrefix: prefix,
          parentBranch: parentBranch,
        );
      },
    );

    final driver = createResult.value;
    if (createResult.isFailure || driver == null) {
      throw AppError(
        ErrorCode.processSpawnFailed,
        message: createResult.error ?? 'Failed to create session',
      );
    }

    // Initialize chat session
    final chatSession = ChatSession(id: id);
    _chatSessions[id] = chatSession;
    _drivers[id] = driver;

    // Subscribe to message stream
    _messageSubscriptions[id] = driver.messageStream.listen((message) {
      _handleMessage(id, message);
    });

    // Determine worktree path from driver
    final worktreePath = driver.worktreePath;

    final session = Session(
      id: id,
      number: number,
      name: name.isEmpty ? 'Session #$number' : name,
      repoPath: repoPath,
      worktreePath: worktreePath,
      gitBranch: branchName,
      agentType: agentType,
      status: SessionStatus.running,
    );

    _sessions.add(session);
    await _sessionStore.save(session);

    _activeSessionId = session.id;

    // Start watching git changes
    _startGitWatcher(id, worktreePath);

    notifyListeners();

    return session;
  }

  void _startGitWatcher(String sessionId, String worktreePath) {
    _gitWatchSubscriptions[sessionId]?.cancel();
    final watcher = _buildGitWatcher(worktreePath);
    _gitWatchSubscriptions[sessionId] = watcher
        .watch(
      interval: const Duration(seconds: 3),
      onError: (error) {
        if (settings.app.debugMode) {
          _appendSystemMessage(sessionId, 'git watcher error: $error');
        }
      },
    )
        .listen((changes) {
      _gitChanges[sessionId] = changes;
      notifyListeners();
    });
  }

  GitWatcher<GitChangesSummary> _buildGitWatcher(String worktreePath) {
    return GitWatcher<GitChangesSummary>(
      fetch: () => GitStatusService.getChanges(worktreePath),
    );
  }

  Future<void> _refreshGitChanges(String sessionId, String worktreePath) async {
    try {
      final changes = await _buildGitWatcher(worktreePath).refreshOnce();
      _gitChanges[sessionId] = changes;
      notifyListeners();
    } catch (e) {
      // Ignore errors, keep previous state
    }
  }

  /// Manually refresh git changes for a session
  Future<void> refreshGitChanges(String sessionId) async {
    final session = _sessions.cast<Session?>().firstWhere(
          (s) => s?.id == sessionId,
          orElse: () => null,
        );
    if (session != null) {
      await _refreshGitChanges(sessionId, session.worktreePath);
    }
  }

  void _handleMessage(String sessionId, ChatMessage message) {
    final currentSession = _chatSessions[sessionId];
    if (currentSession == null) return;

    ChatSession updated;

    // Check if this is an update to an existing message (streaming)
    final existingIndex = currentSession.messages.indexWhere(
      (m) => m.id == message.id,
    );

    if (existingIndex >= 0) {
      // Update existing message
      updated = currentSession.updateMessage(message.id, message);
    } else {
      // Add new message
      updated = currentSession.addMessage(message);
    }

    // Update typing/thinking state
    final isThinking = (message.role == MessageRole.user &&
            message.status == MessageStatus.sent) ||
        (message.role == MessageRole.assistant &&
            message.status == MessageStatus.streaming);
    final isDone = (message.role == MessageRole.assistant &&
            message.status == MessageStatus.complete) ||
        message.status == MessageStatus.error;

    final isTyping = isDone ? false : isThinking;
    updated = updated.copyWith(
      isAgentTyping: isTyping,
      currentStreamingMessageId: isTyping ? message.id : null,
    );

    _chatSessions[sessionId] = updated;

    // Reflect error state in session metadata for header feedback.
    final sessionIndex = _sessions.indexWhere((s) => s.id == sessionId);
    if (sessionIndex >= 0) {
      if (message.status == MessageStatus.error) {
        _sessions[sessionIndex] =
            _sessions[sessionIndex].copyWith(status: SessionStatus.error);
      } else if (isTyping &&
          _sessions[sessionIndex].status == SessionStatus.error) {
        _sessions[sessionIndex] =
            _sessions[sessionIndex].copyWith(status: SessionStatus.running);
      }
    }

    notifyListeners();

    // Save chat when message completes (not during streaming)
    if (message.status == MessageStatus.complete ||
        message.status == MessageStatus.error) {
      _chatStore.save(updated);
    }
  }

  Future<void> sendMessage(String sessionId, String content) async {
    final chatSession = _chatSessions[sessionId];
    if (chatSession != null) {
      _chatSessions[sessionId] = chatSession.copyWith(
        isAgentTyping: true,
        currentStreamingMessageId: null,
      );
    }

    final sessionIndex = _sessions.indexWhere((s) => s.id == sessionId);
    if (sessionIndex >= 0 &&
        _sessions[sessionIndex].status == SessionStatus.error) {
      _sessions[sessionIndex] =
          _sessions[sessionIndex].copyWith(status: SessionStatus.running);
    }
    notifyListeners();

    final driver = await _ensureSessionDriver(sessionId);
    if (driver == null) {
      _emitSendError(sessionId, 'Session driver could not be initialized');
      return;
    }

    if (settings.app.debugMode) {
      _appendSystemMessage(
        sessionId,
        'debug> ${driver.debugCommandForMessage(content)}',
      );
    }

    final sendResult = await _opsCoordinator.sendMessageFlow<void>(
      sessionId: sessionId,
      execute: () => driver.sendMessage(content),
    );

    if (sendResult.isFailure) {
      _emitSendError(sessionId, sendResult.error ?? 'Unknown send error');
    }
  }

  Future<AgentDriver?> _ensureSessionDriver(String sessionId) async {
    final existing = _drivers[sessionId];
    if (existing != null) return existing;

    final session = _sessions.cast<Session?>().firstWhere(
          (s) => s?.id == sessionId,
          orElse: () => null,
        );
    if (session == null) return null;

    try {
      final driver = AgentDriver(
        sessionId: session.id,
        agentType: session.agentType,
        worktreePath: session.worktreePath,
      );

      await driver.start();
      _drivers[sessionId] = driver;

      _messageSubscriptions[sessionId] = driver.messageStream.listen((message) {
        _handleMessage(sessionId, message);
      });

      return driver;
    } catch (_) {
      return null;
    }
  }

  void _emitSendError(String sessionId, String error) {
    final current = _chatSessions[sessionId];
    if (current == null) return;

    final message = ChatMessage(
      id: 'error-${DateTime.now().millisecondsSinceEpoch}',
      role: MessageRole.system,
      content: 'Failed to send message: $error',
      timestamp: DateTime.now(),
      status: MessageStatus.error,
      error: error,
    );

    _chatSessions[sessionId] =
        current.addMessage(message).copyWith(isAgentTyping: false);
    unawaited(_chatStore.save(_chatSessions[sessionId]!));

    final sessionIndex = _sessions.indexWhere((s) => s.id == sessionId);
    if (sessionIndex >= 0) {
      _sessions[sessionIndex] =
          _sessions[sessionIndex].copyWith(status: SessionStatus.error);
    }

    notifyListeners();
  }

  void _appendSystemMessage(String sessionId, String content) {
    final current = _chatSessions[sessionId];
    if (current == null) return;

    final message = ChatMessage(
      id: 'system-${DateTime.now().millisecondsSinceEpoch}',
      role: MessageRole.system,
      content: content,
      timestamp: DateTime.now(),
      status: MessageStatus.complete,
    );

    _chatSessions[sessionId] = current.addMessage(message);
    notifyListeners();
  }

  void setActiveSession(String sessionId) {
    _activeSessionId = sessionId;
    notifyListeners();
  }

  Future<void> renameSession(String sessionId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index < 0) return;

    _sessions[index] = _sessions[index].copyWith(name: trimmed);
    await _sessionStore.save(_sessions[index]);
    notifyListeners();
  }

  Future<void> stopAgent(String sessionId) async {
    final driver = _drivers[sessionId];
    if (driver == null) return;

    await driver.stop();

    // Update session status
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index >= 0) {
      _sessions[index] = _sessions[index].copyWith(status: SessionStatus.idle);
      await _sessionStore.save(_sessions[index]);
    }

    // Update chat session typing state
    final chatSession = _chatSessions[sessionId];
    if (chatSession != null) {
      _chatSessions[sessionId] = chatSession.copyWith(
        isAgentTyping: false,
        currentStreamingMessageId: null,
      );
    }

    notifyListeners();
  }

  Future<void> restartAgent(String sessionId) async {
    final session = _sessions.cast<Session?>().firstWhere(
          (s) => s?.id == sessionId,
          orElse: () => null,
        );
    if (session == null) return;

    // Stop existing driver if any
    await _drivers[sessionId]?.stop();
    _messageSubscriptions[sessionId]?.cancel();

    // Create new driver bound to the existing session worktree.
    final driver = AgentDriver(
      sessionId: sessionId,
      agentType: session.agentType,
      worktreePath: session.worktreePath,
    );
    await driver.start();

    _drivers[sessionId] = driver;

    // Subscribe to messages
    _messageSubscriptions[sessionId] = driver.messageStream.listen((message) {
      _handleMessage(sessionId, message);
    });

    // Update session status
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index >= 0) {
      _sessions[index] =
          _sessions[index].copyWith(status: SessionStatus.running);
      await _sessionStore.save(_sessions[index]);
    }

    notifyListeners();
  }

  Future<void> closeSession(String sessionId,
      {bool cleanupWorktree = true}) async {
    final session = _sessions.cast<Session?>().firstWhere(
          (s) => s?.id == sessionId,
          orElse: () => null,
        );

    if (session == null) return;

    await _opsCoordinator.closeSessionFlow<void>(
      sessionId: sessionId,
      execute: () async {
        // Stop driver (best effort)
        try {
          await _drivers[sessionId]?.stop();
        } catch (_) {
          // Ignore stop errors so session can still be closed
        }
        _drivers.remove(sessionId);

        // Cancel subscription
        try {
          await _messageSubscriptions[sessionId]?.cancel();
        } catch (_) {
          // Ignore subscription cancel errors
        }
        _messageSubscriptions.remove(sessionId);

        // Stop git watcher
        await _gitWatchSubscriptions[sessionId]?.cancel();
        _gitWatchSubscriptions.remove(sessionId);
        _gitChanges.remove(sessionId);
        _terminalOpenSessions.remove(sessionId);

        // Save and remove chat session
        final chatSession = _chatSessions[sessionId];
        if (chatSession != null) {
          await _chatStore.save(chatSession);
        }
        _chatSessions.remove(sessionId);

        _sessions.removeWhere((s) => s.id == sessionId);
        await _sessionStore.delete(sessionId);
        await _chatStore.delete(sessionId);

        if (_activeSessionId == sessionId) {
          _activeSessionId = _sessions.isNotEmpty ? _sessions.first.id : null;
        }

        // Update UI immediately even if cleanup fails.
        notifyListeners();

        if (cleanupWorktree) {
          try {
            await _cleanupWorktree(session.worktreePath, session.repoPath);
          } catch (_) {
            // Ignore cleanup errors; session is already closed in UI/state.
          }
        }
      },
    );
  }

  Future<void> _cleanupWorktree(String worktreePath, String repoPath) async {
    final result = await Process.run(
      'git',
      ['worktree', 'remove', worktreePath, '--force'],
      workingDirectory: repoPath,
    );

    if (result.exitCode != 0) {
      throw AppError(
        ErrorCode.worktreeRemovalFailed,
        message: 'Failed to remove worktree',
        details: result.stderr.toString(),
      );
    }
  }

  @override
  void dispose() {
    // Clean up all subscriptions and drivers
    for (final sub in _messageSubscriptions.values) {
      sub.cancel();
    }
    for (final driver in _drivers.values) {
      driver.dispose();
    }
    for (final subscription in _gitWatchSubscriptions.values) {
      subscription.cancel();
    }
    _opsEventsSubscription?.cancel();
    _opsLogger?.dispose();
    super.dispose();
  }
}
