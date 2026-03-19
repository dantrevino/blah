import 'package:flutter_test/flutter_test.dart';
import 'package:riot/ops/in_memory_ops_logger.dart';
import 'package:riot/ops/models/operation_record.dart';

void main() {
  test('logger rejects invalid maxEntries values', () {
    expect(
      () => InMemoryOpsLogger(maxEntries: 0),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('logger keeps recent operations bounded', () {
    final logger = InMemoryOpsLogger(maxEntries: 2);

    logger.started(
      OperationRecord.started(
        kind: OperationKind.refreshGit,
        sessionId: 's-1',
      ),
    );
    logger.started(
      OperationRecord.started(
        kind: OperationKind.refreshGit,
        sessionId: 's-1',
      ),
    );
    logger.started(
      OperationRecord.started(
        kind: OperationKind.refreshGit,
        sessionId: 's-1',
      ),
    );

    expect(logger.entries.length, 2);
  });

  test('logger emits operation events', () async {
    final logger = InMemoryOpsLogger();
    final emitted = <OperationRecord>[];
    final sub = logger.events.listen(emitted.add);

    logger.failed(
      OperationRecord.started(
        kind: OperationKind.sendMessage,
        sessionId: 's-2',
      ).failed('boom'),
    );

    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(emitted.length, 1);
    expect(emitted.first.status, OperationStatus.failed);
    expect(emitted.first.error, 'boom');
  });
}
