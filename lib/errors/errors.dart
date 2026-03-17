enum ErrorCode {
  gitNotFound,
  notAGitRepo,
  worktreeCreationFailed,
  agentNotFound,
  processSpawnFailed,
  invalidRepoPath,
  sessionCorrupted,
  terminalInitFailed,
}

class BlahError implements Exception {
  final ErrorCode code;
  final String message;
  final String? details;
  final String? recoveryHint;

  BlahError(
    this.code, {
    required this.message,
    this.details,
    this.recoveryHint,
  });

  @override
  String toString() => 'BlahError: $message';
}
