import '../../errors/errors.dart';
import 'command_runner.dart';

class WorktreeOps {
  WorktreeOps(this._runner);

  final CommandRunner _runner;

  static List<String> buildCreateArgs({
    required String branchName,
    required String worktreePath,
    required String parentBranch,
  }) {
    return ['worktree', 'add', '-b', branchName, worktreePath, parentBranch];
  }

  Future<void> create({
    required String repoPath,
    required String branchName,
    required String worktreePath,
    required String parentBranch,
  }) async {
    try {
      final out = await _runner.run(
        'git',
        buildCreateArgs(
          branchName: branchName,
          worktreePath: worktreePath,
          parentBranch: parentBranch,
        ),
        workingDirectory: repoPath,
      );

      if (!out.ok) {
        throw AppError(
          ErrorCode.worktreeCreationFailed,
          message: 'Failed to create worktree',
          details: out.stderr,
        );
      }
    } catch (error) {
      if (error is AppError) rethrow;
      throw AppError(
        ErrorCode.worktreeCreationFailed,
        message: 'Failed to create worktree',
        details: error.toString(),
      );
    }
  }

  Future<void> remove({
    required String repoPath,
    required String worktreePath,
  }) async {
    try {
      final out = await _runner.run(
        'git',
        ['worktree', 'remove', worktreePath, '--force'],
        workingDirectory: repoPath,
      );

      if (!out.ok) {
        throw AppError(
          ErrorCode.worktreeRemovalFailed,
          message: 'Failed to remove worktree',
          details: out.stderr,
        );
      }
    } catch (error) {
      if (error is AppError) rethrow;
      throw AppError(
        ErrorCode.worktreeRemovalFailed,
        message: 'Failed to remove worktree',
        details: error.toString(),
      );
    }
  }
}
