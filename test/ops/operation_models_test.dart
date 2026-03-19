import 'package:flutter_test/flutter_test.dart';
import 'package:riot/ops/models/operation_record.dart';
import 'package:riot/ops/models/operation_result.dart';

void main() {
  test('OperationResult.success stores value', () {
    final result = OperationResult<int>.success(1);

    expect(result.isSuccess, true);
    expect(result.isFailure, false);
    expect(result.value, 1);
    expect(result.error, null);
  });

  test('OperationResult.failure sets failure state', () {
    final result = OperationResult<int>.failure('boom');

    expect(result.isSuccess, false);
    expect(result.isFailure, true);
    expect(result.value, null);
    expect(result.error, 'boom');
  });

  test('OperationResult.failure rejects empty message', () {
    expect(
      () => OperationResult<int>.failure(''),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('OperationRecord transitions to completed', () {
    final started = OperationRecord.started(
      kind: OperationKind.createSession,
      sessionId: 's-1',
    );

    final done = started.completed();

    expect(done.status, OperationStatus.completed);
    expect(done.endedAt, isNotNull);
  });

  test('OperationRecord transitions to failed', () {
    final started = OperationRecord.started(
      kind: OperationKind.sendMessage,
      sessionId: 's-1',
    );

    final failed = started.failed('network timeout');

    expect(failed.status, OperationStatus.failed);
    expect(failed.endedAt, isNotNull);
    expect(failed.error, 'network timeout');
  });

  test('OperationRecord completed only from running', () {
    final started = OperationRecord.started(
      kind: OperationKind.refreshGit,
      sessionId: 's-1',
    );
    final done = started.completed();

    expect(() => done.completed(), throwsA(isA<StateError>()));
  });

  test('OperationRecord failed only from running', () {
    final started = OperationRecord.started(
      kind: OperationKind.closeSession,
      sessionId: 's-1',
    );
    final failed = started.failed('bad state');

    expect(() => failed.failed('other failure'), throwsA(isA<StateError>()));
  });

  test('OperationRecord.started rejects invalid attempt', () {
    expect(
      () => OperationRecord.started(
        kind: OperationKind.createSession,
        sessionId: 's-1',
        attempt: 0,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('OperationRecord.started rejects empty sessionId', () {
    expect(
      () => OperationRecord.started(
        kind: OperationKind.createSession,
        sessionId: '   ',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('OperationRecord.failed rejects empty reason', () {
    final started = OperationRecord.started(
      kind: OperationKind.sendMessage,
      sessionId: 's-1',
    );

    expect(() => started.failed(' '), throwsA(isA<ArgumentError>()));
  });
}
