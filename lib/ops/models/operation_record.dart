enum OperationKind { createSession, sendMessage, refreshGit, closeSession }

enum OperationStatus { running, completed, failed }

class OperationRecord {
  final String id;
  final OperationKind kind;
  final String sessionId;
  final OperationStatus status;
  final int attempt;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? error;

  const OperationRecord({
    required this.id,
    required this.kind,
    required this.sessionId,
    required this.status,
    required this.attempt,
    required this.startedAt,
    this.endedAt,
    this.error,
  });

  factory OperationRecord.started({
    required OperationKind kind,
    required String sessionId,
    int attempt = 1,
  }) {
    if (attempt < 1) {
      throw ArgumentError.value(attempt, 'attempt', 'must be >= 1');
    }
    if (sessionId.trim().isEmpty) {
      throw ArgumentError.value(sessionId, 'sessionId', 'must not be empty');
    }
    final now = DateTime.now();
    return OperationRecord(
      id: '${kind.name}-${now.microsecondsSinceEpoch}',
      kind: kind,
      sessionId: sessionId,
      status: OperationStatus.running,
      attempt: attempt,
      startedAt: now,
    );
  }

  OperationRecord completed() {
    if (status != OperationStatus.running) {
      throw StateError('Operation can only complete from running status');
    }
    return OperationRecord(
      id: id,
      kind: kind,
      sessionId: sessionId,
      status: OperationStatus.completed,
      attempt: attempt,
      startedAt: startedAt,
      endedAt: DateTime.now(),
    );
  }

  OperationRecord failed(String reason) {
    if (status != OperationStatus.running) {
      throw StateError('Operation can only fail from running status');
    }
    if (reason.trim().isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'must not be empty');
    }
    return OperationRecord(
      id: id,
      kind: kind,
      sessionId: sessionId,
      status: OperationStatus.failed,
      attempt: attempt,
      startedAt: startedAt,
      endedAt: DateTime.now(),
      error: reason,
    );
  }
}
