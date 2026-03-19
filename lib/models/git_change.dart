/// Status of a file change in git
enum FileChangeStatus {
  added, // New file (A)
  modified, // Modified file (M)
  deleted, // Deleted file (D)
  renamed, // Renamed file (R)
  copied, // Copied file (C)
  untracked, // Untracked file (?)
  staged, // Staged for commit
}

/// Represents a single file change in git
class GitChange {
  final String path;
  final String? oldPath; // For renames
  final FileChangeStatus status;
  final int additions;
  final int deletions;
  final bool isStaged;

  const GitChange({
    required this.path,
    this.oldPath,
    required this.status,
    this.additions = 0,
    this.deletions = 0,
    this.isStaged = false,
  });

  /// Total lines changed
  int get totalChanges => additions + deletions;

  /// File extension
  String get extension {
    final parts = path.split('.');
    return parts.length > 1 ? parts.last : '';
  }

  /// File name without path
  String get fileName {
    final parts = path.split('/');
    return parts.last;
  }

  /// Directory path
  String get directory {
    final parts = path.split('/');
    if (parts.length > 1) {
      return parts.sublist(0, parts.length - 1).join('/');
    }
    return '';
  }

  GitChange copyWith({
    String? path,
    String? oldPath,
    FileChangeStatus? status,
    int? additions,
    int? deletions,
    bool? isStaged,
  }) {
    return GitChange(
      path: path ?? this.path,
      oldPath: oldPath ?? this.oldPath,
      status: status ?? this.status,
      additions: additions ?? this.additions,
      deletions: deletions ?? this.deletions,
      isStaged: isStaged ?? this.isStaged,
    );
  }
}

/// Summary of all changes in a session
class GitChangesSummary {
  final List<GitChange> changes;
  final int totalAdditions;
  final int totalDeletions;
  final int filesChanged;
  final String? branch;
  final String? baseBranch;
  final int? commitsAhead;

  const GitChangesSummary({
    this.changes = const [],
    this.totalAdditions = 0,
    this.totalDeletions = 0,
    this.filesChanged = 0,
    this.branch,
    this.baseBranch,
    this.commitsAhead,
  });

  static const empty = GitChangesSummary();

  bool get hasChanges => changes.isNotEmpty;

  /// Group changes by directory
  Map<String, List<GitChange>> get changesByDirectory {
    final grouped = <String, List<GitChange>>{};
    for (final change in changes) {
      final dir = change.directory.isEmpty ? '.' : change.directory;
      grouped.putIfAbsent(dir, () => []).add(change);
    }
    return grouped;
  }
}
