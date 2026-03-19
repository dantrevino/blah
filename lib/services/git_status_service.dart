import 'dart:async';
import 'dart:io';
import '../models/git_change.dart';

/// Service to get git status and diff information for a worktree
class GitStatusService {
  /// Get the changes summary for a worktree compared to its base branch
  static Future<GitChangesSummary> getChanges(
    String worktreePath, {
    String? baseBranch,
  }) async {
    try {
      // Get current branch
      final branchResult = await Process.run(
        'git',
        ['rev-parse', '--abbrev-ref', 'HEAD'],
        workingDirectory: worktreePath,
      );
      final currentBranch = branchResult.stdout.toString().trim();

      // Determine base branch if not provided
      baseBranch ??= await _findBaseBranch(worktreePath);

      // Get status (staged and unstaged changes)
      final statusChanges = await _getStatusChanges(worktreePath);

      // Get diff stats against base branch
      final diffChanges = await _getDiffStats(worktreePath, baseBranch);

      // Merge status and diff info
      final mergedChanges = _mergeChanges(statusChanges, diffChanges);

      // Calculate totals
      int totalAdditions = 0;
      int totalDeletions = 0;
      for (final change in mergedChanges) {
        totalAdditions += change.additions;
        totalDeletions += change.deletions;
      }

      // Get commits ahead count
      final commitsAhead = await _getCommitsAhead(worktreePath, baseBranch);

      return GitChangesSummary(
        changes: mergedChanges,
        totalAdditions: totalAdditions,
        totalDeletions: totalDeletions,
        filesChanged: mergedChanges.length,
        branch: currentBranch,
        baseBranch: baseBranch,
        commitsAhead: commitsAhead,
      );
    } catch (e) {
      return GitChangesSummary.empty;
    }
  }

  /// Find the base branch (usually main or master)
  static Future<String> _findBaseBranch(String worktreePath) async {
    // Try common base branch names
    for (final branch in ['main', 'master', 'develop']) {
      final result = await Process.run(
        'git',
        ['rev-parse', '--verify', branch],
        workingDirectory: worktreePath,
      );
      if (result.exitCode == 0) {
        return branch;
      }
    }
    return 'HEAD~10'; // Fallback to last 10 commits
  }

  /// Get changes from git status
  static Future<List<GitChange>> _getStatusChanges(String worktreePath) async {
    final result = await Process.run(
      'git',
      ['status', '--porcelain', '-uall'],
      workingDirectory: worktreePath,
    );

    if (result.exitCode != 0) return [];

    final changes = <GitChange>[];
    final lines = result.stdout.toString().split('\n');

    for (final line in lines) {
      if (line.length < 3) continue;

      final indexStatus = line[0];
      final workTreeStatus = line[1];
      final path = line.substring(3).trim();

      // Handle renames (format: "R  old -> new")
      String? oldPath;
      String filePath = path;
      if (path.contains(' -> ')) {
        final parts = path.split(' -> ');
        oldPath = parts[0];
        filePath = parts[1];
      }

      final status = _parseStatus(indexStatus, workTreeStatus);
      final isStaged = indexStatus != ' ' && indexStatus != '?';

      changes.add(GitChange(
        path: filePath,
        oldPath: oldPath,
        status: status,
        isStaged: isStaged,
      ));
    }

    return changes;
  }

  /// Parse git status codes to FileChangeStatus
  static FileChangeStatus _parseStatus(
      String indexStatus, String workTreeStatus) {
    // Prioritize index status if staged
    final status = indexStatus != ' ' ? indexStatus : workTreeStatus;

    switch (status) {
      case 'A':
        return FileChangeStatus.added;
      case 'M':
        return FileChangeStatus.modified;
      case 'D':
        return FileChangeStatus.deleted;
      case 'R':
        return FileChangeStatus.renamed;
      case 'C':
        return FileChangeStatus.copied;
      case '?':
        return FileChangeStatus.untracked;
      default:
        return FileChangeStatus.modified;
    }
  }

  /// Get diff stats (additions/deletions) against base branch
  static Future<Map<String, (int, int)>> _getDiffStats(
    String worktreePath,
    String baseBranch,
  ) async {
    final result = await Process.run(
      'git',
      ['diff', '--numstat', baseBranch],
      workingDirectory: worktreePath,
    );

    if (result.exitCode != 0) return {};

    final stats = <String, (int, int)>{};
    final lines = result.stdout.toString().split('\n');

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      final parts = line.split('\t');
      if (parts.length < 3) continue;

      final additions = int.tryParse(parts[0]) ?? 0;
      final deletions = int.tryParse(parts[1]) ?? 0;
      final path = parts[2];

      // Handle renames
      String filePath = path;
      if (path.contains(' => ')) {
        // Format: dir/{old => new}/file or old => new
        filePath = path.replaceAllMapped(
          RegExp(r'\{([^}]+) => ([^}]+)\}'),
          (m) => m.group(2)!,
        );
        if (filePath.contains(' => ')) {
          filePath = filePath.split(' => ').last;
        }
      }

      stats[filePath] = (additions, deletions);
    }

    return stats;
  }

  /// Merge status changes with diff stats
  static List<GitChange> _mergeChanges(
    List<GitChange> statusChanges,
    Map<String, (int, int)> diffStats,
  ) {
    final merged = <GitChange>[];

    for (final change in statusChanges) {
      final stats = diffStats[change.path];
      if (stats != null) {
        merged.add(change.copyWith(
          additions: stats.$1,
          deletions: stats.$2,
        ));
      } else {
        merged.add(change);
      }
    }

    // Add any files in diff that aren't in status (committed but not pushed)
    for (final entry in diffStats.entries) {
      final exists = statusChanges.any((c) => c.path == entry.key);
      if (!exists) {
        merged.add(GitChange(
          path: entry.key,
          status: FileChangeStatus.modified,
          additions: entry.value.$1,
          deletions: entry.value.$2,
          isStaged: true,
        ));
      }
    }

    // Sort by path
    merged.sort((a, b) => a.path.compareTo(b.path));

    return merged;
  }

  /// Get number of commits ahead of base branch
  static Future<int> _getCommitsAhead(
    String worktreePath,
    String baseBranch,
  ) async {
    final result = await Process.run(
      'git',
      ['rev-list', '--count', '$baseBranch..HEAD'],
      workingDirectory: worktreePath,
    );

    if (result.exitCode != 0) return 0;
    return int.tryParse(result.stdout.toString().trim()) ?? 0;
  }

  /// Watch for changes in the worktree (polls every few seconds)
  static Stream<GitChangesSummary> watchChanges(
    String worktreePath, {
    String? baseBranch,
    Duration interval = const Duration(seconds: 3),
  }) async* {
    while (true) {
      yield await getChanges(worktreePath, baseBranch: baseBranch);
      await Future.delayed(interval);
    }
  }
}
