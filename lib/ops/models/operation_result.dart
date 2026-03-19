class OperationResult<T> {
  final T? value;
  final String? error;

  const OperationResult._({this.value, this.error});

  factory OperationResult.success(T value) => OperationResult._(value: value);

  factory OperationResult.failure(String error) {
    if (error.trim().isEmpty) {
      throw ArgumentError.value(error, 'error', 'must not be empty');
    }
    return OperationResult._(error: error);
  }

  bool get isSuccess => error == null;

  bool get isFailure => !isSuccess;
}
