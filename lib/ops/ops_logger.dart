import 'models/operation_record.dart';

abstract class OpsLogger {
  void started(OperationRecord operation);

  void completed(OperationRecord operation);

  void failed(OperationRecord operation);
}
