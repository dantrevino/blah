import 'package:flutter/material.dart';
import '../../config/branding.dart';
import '../../models/git_change.dart';

/// Right sidebar showing git changes for the current session
class ChangesSidebar extends StatelessWidget {
  final GitChangesSummary summary;
  final VoidCallback? onRefresh;

  const ChangesSidebar({
    required this.summary,
    this.onRefresh,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          _ChangesHeader(
            summary: summary,
            onRefresh: onRefresh,
          ),
          const Divider(height: 1),
          // Changes list
          Expanded(
            child: summary.hasChanges
                ? _ChangesList(changes: summary.changes)
                : _NoChanges(),
          ),
        ],
      ),
    );
  }
}

/// Header with summary stats
class _ChangesHeader extends StatelessWidget {
  final GitChangesSummary summary;
  final VoidCallback? onRefresh;

  const _ChangesHeader({
    required this.summary,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.difference_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Changes',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (onRefresh != null)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: onRefresh,
                  tooltip: 'Refresh (F5)',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (summary.hasChanges) ...[
            const SizedBox(height: 8),
            // Stats row
            Row(
              children: [
                _StatChip(
                  icon: Icons.insert_drive_file_outlined,
                  label: '${summary.filesChanged}',
                  color: theme.colorScheme.outline,
                  tooltip: '${summary.filesChanged} files changed',
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: Icons.add,
                  label: '+${summary.totalAdditions}',
                  color: Colors.green,
                  tooltip: '${summary.totalAdditions} additions',
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: Icons.remove,
                  label: '-${summary.totalDeletions}',
                  color: Colors.red,
                  tooltip: '${summary.totalDeletions} deletions',
                ),
              ],
            ),
            if (summary.commitsAhead != null && summary.commitsAhead! > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${summary.commitsAhead} commit${summary.commitsAhead! > 1 ? 's' : ''} ahead of ${summary.baseBranch}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Small stat chip
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String tooltip;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
              fontFamily: 'JetBrainsMono Nerd Font',
            ),
          ),
        ],
      ),
    );
  }
}

/// Scrollable list of changes
class _ChangesList extends StatelessWidget {
  final List<GitChange> changes;

  const _ChangesList({required this.changes});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: changes.length,
      itemBuilder: (context, index) {
        return _ChangeItem(change: changes[index]);
      },
    );
  }
}

/// Single change item
class _ChangeItem extends StatelessWidget {
  final GitChange change;

  const _ChangeItem({required this.change});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        // TODO: Open diff view for this file
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            // Status icon
            _StatusIcon(status: change.status),
            const SizedBox(width: 8),
            // File info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    change.fileName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (change.directory.isNotEmpty)
                    Text(
                      change.directory,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Change stats
            if (change.additions > 0 || change.deletions > 0)
              _ChangeStats(
                additions: change.additions,
                deletions: change.deletions,
              ),
          ],
        ),
      ),
    );
  }
}

/// Status icon for file change type
class _StatusIcon extends StatelessWidget {
  final FileChangeStatus status;

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _getIconAndColor();

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          _getStatusLetter(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
            fontFamily: 'JetBrainsMono Nerd Font',
          ),
        ),
      ),
    );
  }

  String _getStatusLetter() {
    switch (status) {
      case FileChangeStatus.added:
        return 'A';
      case FileChangeStatus.modified:
        return 'M';
      case FileChangeStatus.deleted:
        return 'D';
      case FileChangeStatus.renamed:
        return 'R';
      case FileChangeStatus.copied:
        return 'C';
      case FileChangeStatus.untracked:
        return 'U';
      case FileChangeStatus.staged:
        return 'S';
    }
  }

  (IconData, Color) _getIconAndColor() {
    switch (status) {
      case FileChangeStatus.added:
        return (Icons.add, Colors.green);
      case FileChangeStatus.modified:
        return (Icons.edit, Colors.orange);
      case FileChangeStatus.deleted:
        return (Icons.delete, Colors.red);
      case FileChangeStatus.renamed:
        return (Icons.drive_file_rename_outline, Colors.blue);
      case FileChangeStatus.copied:
        return (Icons.content_copy, Colors.purple);
      case FileChangeStatus.untracked:
        return (Icons.help_outline, Colors.grey);
      case FileChangeStatus.staged:
        return (Icons.check, Branding.primaryColor);
    }
  }
}

/// Additions/deletions mini bar
class _ChangeStats extends StatelessWidget {
  final int additions;
  final int deletions;

  const _ChangeStats({
    required this.additions,
    required this.deletions,
  });

  @override
  Widget build(BuildContext context) {
    final total = additions + deletions;
    if (total == 0) return const SizedBox.shrink();

    // Calculate proportions for the mini bar
    final addProportion = additions / total;
    const maxWidth = 50.0;

    return SizedBox(
      width: maxWidth + 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Mini bar
          SizedBox(
            width: maxWidth,
            height: 6,
            child: Row(
              children: [
                if (additions > 0)
                  Expanded(
                    flex: (addProportion * 100).round(),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(2),
                        ),
                      ),
                    ),
                  ),
                if (deletions > 0)
                  Expanded(
                    flex: ((1 - addProportion) * 100).round(),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.horizontal(
                          right: Radius.circular(2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state when no changes
class _NoChanges extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'No changes',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Working directory clean',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
