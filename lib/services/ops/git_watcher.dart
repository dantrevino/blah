import 'dart:async';

typedef FetchSnapshot<T> = Future<T> Function();
typedef OnWatcherError = void Function(Object error);

class GitWatcher<T> {
  GitWatcher({required FetchSnapshot<T> fetch}) : _fetch = fetch;

  final FetchSnapshot<T> _fetch;

  Stream<T> watch({
    Duration interval = const Duration(seconds: 3),
    OnWatcherError? onError,
  }) async* {
    while (true) {
      T snapshot;
      try {
        snapshot = await _fetch();
      } catch (error) {
        onError?.call(error);
        await Future<void>.delayed(interval);
        continue;
      }

      yield snapshot;
      await Future<void>.delayed(interval);
    }
  }

  Future<T> refreshOnce() => _fetch();
}
