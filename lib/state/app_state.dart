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

  Future<void> closeSession(String sessionId,
      {bool cleanupWorktree = true}) async {
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
