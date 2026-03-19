import 'models/operation_record.dart';
import 'models/operation_result.dart';
import 'ops_logger.dart';

class NoopOpsLogger implements OpsLogger {
  const NoopOpsLogger();

  @override
  void completed(OperationRecord operation) {}

  @override
  void failed(OperationRecord operation) {}

  @override
  void started(OperationRecord operation) {}
}

class OpsCoordinator {
  OpsCoordinator({required OpsLogger logger}) : _logger = logger;

  final OpsLogger _logger;

  Future<OperationResult<T>> createSessionFlow<T>({
    required String sessionId,
    required Future<T> Function() execute,
    int attempt = 1,
  }) {
    return _runOperation(
      kind: OperationKind.createSession,
      sessionId: sessionId,
      attempt: attempt,
      execute: execute,
    );
  }

  Future<OperationResult<T>> sendMessageFlow<T>({
    required String sessionId,
    required Future<T> Function() execute,
    int attempt = 1,
  }) {
    return _runOperation(
      kind: OperationKind.sendMessage,
      sessionId: sessionId,
      attempt: attempt,
      execute: execute,
    );
  }

  Future<OperationResult<T>> closeSessionFlow<T>({
    required String sessionId,
    required Future<T> Function() execute,
    int attempt = 1,
  }) {
    return _runOperation(
      kind: OperationKind.closeSession,
      sessionId: sessionId,
      attempt: attempt,
      execute: execute,
    );
  }

  Future<OperationResult<T>> _runOperation<T>({
    required OperationKind kind,
    required String sessionId,
    required int attempt,
    required Future<T> Function() execute,
  }) async {
    final operation = OperationRecord.started(
      kind: kind,
      sessionId: sessionId,
      attempt: attempt,
    );

    _logger.started(operation);

    try {
      final value = await execute();
      _logger.completed(operation.completed());
      return OperationResult.success(value);
    } catch (error) {
      final errorText = error.toString();
      _logger.failed(operation.failed(errorText));
      return OperationResult.failure(errorText);
    }
  }
}
