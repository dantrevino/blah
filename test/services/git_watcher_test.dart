import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:riot/services/ops/git_watcher.dart';

void main() {
  test('GitWatcher emits first snapshot immediately', () async {
    var calls = 0;
    final watcher = GitWatcher<int>(fetch: () async {
      calls += 1;
      return calls;
    });

    final values = <int>[];
    final sub = watcher
        .watch(interval: const Duration(milliseconds: 20))
        .listen(values.add);

    await Future<void>.delayed(const Duration(milliseconds: 30));
    await sub.cancel();

    expect(values.isNotEmpty, true);
    expect(values.first, 1);
  });

  test('GitWatcher emits periodic updates', () async {
    var calls = 0;
    final watcher = GitWatcher<int>(fetch: () async {
      calls += 1;
      return calls;
    });

    final values = <int>[];
    final done = Completer<void>();
    late StreamSubscription<int> sub;
    sub = watcher
        .watch(interval: const Duration(milliseconds: 10))
        .listen((value) {
      values.add(value);
      if (values.length >= 3 && !done.isCompleted) {
        done.complete();
      }
    });

    await done.future.timeout(const Duration(seconds: 1));
    await sub.cancel();

    expect(values, [1, 2, 3]);
  });

  test('GitWatcher ignores fetch errors and keeps previous state', () async {
    var calls = 0;
    final watcher = GitWatcher<int>(fetch: () async {
      calls += 1;
      if (calls == 2) {
        throw Exception('transient failure');
      }
      if (calls == 3) {
        return 3;
      }
      return 1;
    });

    final values = <int>[];
    final done = Completer<void>();
    late StreamSubscription<int> sub;
    sub = watcher.watch(interval: const Duration(milliseconds: 15)).listen(
        (value) {
      values.add(value);
      if (value == 3 && !done.isCompleted) {
        done.complete();
      }
    }, onError: (Object error, StackTrace stackTrace) {
      fail('watch stream should not emit errors: $error');
    });

    await done.future.timeout(const Duration(seconds: 1));
    await sub.cancel();

    expect(values, [1, 3]);
  });

  test('GitWatcher refreshOnce delegates to fetch', () async {
    final watcher = GitWatcher<String>(fetch: () async => 'snapshot');

    final value = await watcher.refreshOnce();

    expect(value, 'snapshot');
  });

  test('GitWatcher calls onError when fetch fails', () async {
    var calls = 0;
    Object? captured;
    final watcher = GitWatcher<int>(fetch: () async {
      calls += 1;
      if (calls == 1) {
        throw Exception('boom');
      }
      return 2;
    });

    final values = <int>[];
    final done = Completer<void>();
    late StreamSubscription<int> sub;
    sub = watcher
        .watch(
      interval: const Duration(milliseconds: 10),
      onError: (error) => captured = error,
    )
        .listen((value) {
      values.add(value);
      if (value == 2 && !done.isCompleted) {
        done.complete();
      }
    });

    await done.future.timeout(const Duration(seconds: 1));
    await sub.cancel();

    expect(captured, isNotNull);
    expect(values, [2]);
  });
}
