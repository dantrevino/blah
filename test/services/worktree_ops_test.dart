import 'package:flutter_test/flutter_test.dart';
import 'package:riot/errors/errors.dart';
import 'package:riot/services/ops/command_runner.dart';
import 'package:riot/services/ops/worktree_ops.dart';

class _FakeCommandRunner extends CommandRunner {
  _FakeCommandRunner({required this.outcome});

  CommandOutcome outcome;
  Object? errorToThrow;
  String? executable;
  List<String>? args;
  String? workingDirectory;

  @override
  Future<CommandOutcome> run(
    String executable,
    List<String> args, {
    String? workingDirectory,
  }) async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    this.executable = executable;
    this.args = args;
    this.workingDirectory = workingDirectory;
    return outcome;
  }
}

void main() {
  test('buildCreateArgs uses worktree add -b', () {
    final args = WorktreeOps.buildCreateArgs(
      branchName: 'riot/s-1',
      worktreePath: '/tmp/repo/.riot/worktrees/riot/s-1',
      parentBranch: 'main',
    );

    expect(args, [
      'worktree',
      'add',
      '-b',
      'riot/s-1',
      '/tmp/repo/.riot/worktrees/riot/s-1',
      'main',
    ]);
  });

  test('create executes git worktree add command', () async {
    final runner = _FakeCommandRunner(
      outcome: const CommandOutcome(0, '', ''),
    );
    final ops = WorktreeOps(runner);

    await ops.create(
      repoPath: '/tmp/repo',
      branchName: 'riot/s-1',
      worktreePath: '/tmp/repo/.riot/worktrees/riot/s-1',
      parentBranch: 'main',
    );

    expect(runner.executable, 'git');
    expect(
      runner.args,
      [
        'worktree',
        'add',
        '-b',
        'riot/s-1',
        '/tmp/repo/.riot/worktrees/riot/s-1',
        'main',
      ],
    );
    expect(runner.workingDirectory, '/tmp/repo');
  });

  test('create maps command failure to AppError', () async {
    final runner = _FakeCommandRunner(
      outcome: const CommandOutcome(1, '', 'fatal: failed'),
    );
    final ops = WorktreeOps(runner);

    expect(
      () => ops.create(
        repoPath: '/tmp/repo',
        branchName: 'riot/s-1',
        worktreePath: '/tmp/repo/.riot/worktrees/riot/s-1',
        parentBranch: 'main',
      ),
      throwsA(
        isA<AppError>()
            .having((e) => e.code, 'code', ErrorCode.worktreeCreationFailed),
      ),
    );
  });

  test('remove maps command failure to AppError', () async {
    final runner = _FakeCommandRunner(
      outcome: const CommandOutcome(1, '', 'fatal: remove failed'),
    );
    final ops = WorktreeOps(runner);

    expect(
      () => ops.remove(
        repoPath: '/tmp/repo',
        worktreePath: '/tmp/repo/.riot/worktrees/riot/s-1',
      ),
      throwsA(
        isA<AppError>()
            .having((e) => e.code, 'code', ErrorCode.worktreeRemovalFailed),
      ),
    );
  });

  test('create maps thrown runner errors to AppError', () async {
    final runner = _FakeCommandRunner(
      outcome: const CommandOutcome(0, '', ''),
    )..errorToThrow = Exception('spawn failed');
    final ops = WorktreeOps(runner);

    expect(
      () => ops.create(
        repoPath: '/tmp/repo',
        branchName: 'riot/s-1',
        worktreePath: '/tmp/repo/.riot/worktrees/riot/s-1',
        parentBranch: 'main',
      ),
      throwsA(
        isA<AppError>()
            .having((e) => e.code, 'code', ErrorCode.worktreeCreationFailed),
      ),
    );
  });

  test('remove executes git worktree remove command', () async {
    final runner = _FakeCommandRunner(
      outcome: const CommandOutcome(0, '', ''),
    );
    final ops = WorktreeOps(runner);

    await ops.remove(
      repoPath: '/tmp/repo',
      worktreePath: '/tmp/repo/.riot/worktrees/riot/s-1',
    );

    expect(runner.executable, 'git');
    expect(
      runner.args,
      ['worktree', 'remove', '/tmp/repo/.riot/worktrees/riot/s-1', '--force'],
    );
    expect(runner.workingDirectory, '/tmp/repo');
  });
}
