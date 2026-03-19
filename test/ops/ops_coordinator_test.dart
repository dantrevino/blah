import 'package:flutter_test/flutter_test.dart';
import 'package:riot/ops/models/operation_record.dart';
import 'package:riot/ops/ops_coordinator.dart';
import 'package:riot/ops/ops_logger.dart';

void main() {
  test('createSessionFlow returns failure when operation throws', () async {
    final logger = _RecordingOpsLogger();
    final coordinator = OpsCoordinator(logger: logger);

    final result = await coordinator.createSessionFlow<void>(
      sessionId: 's-1',
      execute: () async {
        throw Exception('worktree failed');
      },
    );

    expect(result.isSuccess, false);
    expect(result.error, contains('worktree failed'));
    expect(logger.startedKinds, [OperationKind.createSession]);
    expect(logger.failedKinds, [OperationKind.createSession]);
  });

  test('sendMessageFlow returns success and logs completion', () async {
    final logger = _RecordingOpsLogger();
    final coordinator = OpsCoordinator(logger: logger);

    final result = await coordinator.sendMessageFlow<void>(
      sessionId: 's-2',
      execute: () async {},
    );

    expect(result.isSuccess, true);
    expect(logger.startedKinds, [OperationKind.sendMessage]);
    expect(logger.completedKinds, [OperationKind.sendMessage]);
  });

  test('closeSessionFlow logs completion on success', () async {
    final logger = _RecordingOpsLogger();
    final coordinator = OpsCoordinator(logger: logger);

    final result = await coordinator.closeSessionFlow<void>(
      sessionId: 's-3',
      execute: () async {},
    );

    expect(result.isSuccess, true);
    expect(logger.startedKinds, [OperationKind.closeSession]);
    expect(logger.completedKinds, [OperationKind.closeSession]);
    expect(logger.failedKinds, isEmpty);
  });
}

class _RecordingOpsLogger implements OpsLogger {
  final List<OperationKind> startedKinds = <OperationKind>[];
  final List<OperationKind> completedKinds = <OperationKind>[];
  final List<OperationKind> failedKinds = <OperationKind>[];

  @override
  void completed(OperationRecord operation) {
    completedKinds.add(operation.kind);
  }

  @override
  void failed(OperationRecord operation) {
    failedKinds.add(operation.kind);
  }

  @override
  void started(OperationRecord operation) {
    startedKinds.add(operation.kind);
  }
}
