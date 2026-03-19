enum ErrorCode {
  gitNotFound,
  notAGitRepo,
  worktreeCreationFailed,
  worktreeRemovalFailed,
  agentNotFound,
  processSpawnFailed,
  invalidRepoPath,
  sessionCorrupted,
  terminalInitFailed,
}

class AppError implements Exception {
  final ErrorCode code;
  final String message;
  final String? details;
  final String? recoveryHint;

  AppError(
    this.code, {
    required this.message,
    this.details,
    this.recoveryHint,
  });

  @override
  String toString() => 'AppError: $message';
}
