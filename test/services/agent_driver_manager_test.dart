import 'package:flutter_test/flutter_test.dart';
import 'package:riot/models/session.dart';
import 'package:riot/services/agent_driver.dart';
import 'package:riot/services/ops/command_runner.dart';
import 'package:riot/services/ops/worktree_ops.dart';

class _NoopRunner extends CommandRunner {
  @override
  Future<CommandOutcome> run(
    String executable,
    List<String> args, {
    String? workingDirectory,
  }) async {
    return const CommandOutcome(0, '', '');
  }
}

class _FakeWorktreeOps extends WorktreeOps {
  _FakeWorktreeOps() : super(_NoopRunner());

  bool createCalled = false;
  bool removeCalled = false;
  String? createdPath;
  String? removedPath;

  @override
  Future<void> create({
    required String repoPath,
    required String branchName,
    required String worktreePath,
    required String parentBranch,
  }) async {
    createCalled = true;
    createdPath = worktreePath;
  }

  @override
  Future<void> remove({
    required String repoPath,
    required String worktreePath,
  }) async {
    removeCalled = true;
    removedPath = worktreePath;
  }
}

class _FailingStartDriver extends AgentDriver {
  _FailingStartDriver({
    required super.sessionId,
    required super.agentType,
    required super.worktreePath,
  });

  @override
  Future<void> start() async {
    throw Exception('start failed');
  }
}

void main() {
  test('createDriver cleans up worktree when driver start fails', () async {
    final worktreeOps = _FakeWorktreeOps();
    final manager = AgentDriverManager(
      worktreeOps: worktreeOps,
      verifyRepo: (_) async {},
      getCurrentBranch: (_) async => 'main',
      driverFactory: ({
        required String sessionId,
        required AgentType agentType,
        required String worktreePath,
      }) =>
          _FailingStartDriver(
        sessionId: sessionId,
        agentType: agentType,
        worktreePath: worktreePath,
      ),
    );

    await expectLater(
      () => manager.createDriver(
        sessionId: 's-1',
        agentType: AgentType.claude,
        repoPath: '/tmp/repo',
      ),
      throwsException,
    );

    expect(worktreeOps.createCalled, isTrue);
    expect(worktreeOps.removeCalled, isTrue);
    expect(worktreeOps.createdPath, worktreeOps.removedPath);
  });
}
