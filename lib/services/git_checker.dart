import 'dart:io';
import '../errors/errors.dart';

class GitChecker {
  static Future<void> verifyGitAvailable() async {
    final result = await Process.run('git', ['--version']);

    if (result.exitCode != 0) {
      throw BlahError(
        ErrorCode.gitNotFound,
        message: 'Git is not installed or not in PATH',
        recoveryHint: 'Install Git from https://git-scm.com/downloads',
      );
    }
  }

  static Future<void> verifyRepo(String path) async {
    if (!await Directory(path).exists()) {
      throw BlahError(
        ErrorCode.invalidRepoPath,
        message: 'Path does not exist: $path',
      );
    }

    final result = await Process.run(
      'git',
      ['rev-parse', '--is-inside-work-tree'],
      workingDirectory: path,
    );

    if (result.exitCode != 0) {
      throw BlahError(
        ErrorCode.notAGitRepo,
        message: 'Not a git repository: $path',
        recoveryHint: 'Initialize with: git init',
      );
    }
  }

  static Future<String> getCurrentBranch(String path) async {
    final result = await Process.run(
      'git',
      ['rev-parse', '--abbrev-ref', 'HEAD'],
      workingDirectory: path,
    );

    if (result.exitCode != 0) {
      return 'main';
    }

    return result.stdout.toString().trim();
  }

  static Future<bool> branchExists(String path, String branchName) async {
    final result = await Process.run(
      'git',
      ['branch', '--list', branchName],
      workingDirectory: path,
    );

    return result.stdout.toString().trim().isNotEmpty;
  }
}
