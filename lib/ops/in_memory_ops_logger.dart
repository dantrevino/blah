import 'dart:async';

import 'models/operation_record.dart';
import 'ops_logger.dart';

class InMemoryOpsLogger implements OpsLogger {
  InMemoryOpsLogger({int maxEntries = 200})
      : maxEntries = _validateMaxEntries(maxEntries);

  final int maxEntries;
  final List<OperationRecord> _entries = [];
  final StreamController<OperationRecord> _eventsController =
      StreamController<OperationRecord>.broadcast();

  List<OperationRecord> get entries => List.unmodifiable(_entries);
  Stream<OperationRecord> get events => _eventsController.stream;

  @override
  void started(OperationRecord operation) {
    _push(operation);
  }

  @override
  void completed(OperationRecord operation) {
    _push(operation);
  }

  @override
  void failed(OperationRecord operation) {
    _push(operation);
  }

  void dispose() {
    _eventsController.close();
  }

  void _push(OperationRecord operation) {
    _entries.add(operation);
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
    _eventsController.add(operation);
  }

  static int _validateMaxEntries(int value) {
    if (value < 1) {
      throw ArgumentError.value(value, 'maxEntries', 'must be >= 1');
    }
    return value;
  }
}
