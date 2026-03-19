import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../config/branding.dart';
import '../../models/session.dart';
import '../../state/app_state.dart';
import '../session/new_session_dialog.dart';
import '../settings/settings_dialog.dart';
import '../chat/chat_view.dart';
import '../changes/changes_sidebar.dart';
import '../terminal/terminal_panel.dart';
import 'sidebar.dart';

// Custom intents for keyboard shortcuts
class NewSessionIntent extends Intent {
  const NewSessionIntent();
}

class OpenTerminalIntent extends Intent {
  const OpenTerminalIntent();
}

class RefreshIntent extends Intent {
  const RefreshIntent();
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final activeSession = appState.activeSession;

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        // Ctrl+N - New session
        SingleActivator(LogicalKeyboardKey.keyN, control: true):
            NewSessionIntent(),
        // Ctrl+` (backtick) - Open terminal
        SingleActivator(LogicalKeyboardKey.backquote, control: true):
            OpenTerminalIntent(),
        // Ctrl+Shift+` - Alternative for open terminal (common in VS Code)
        SingleActivator(LogicalKeyboardKey.backquote,
            control: true, shift: true): OpenTerminalIntent(),
        // F5 - Refresh
        SingleActivator(LogicalKeyboardKey.f5): RefreshIntent(),
        // Ctrl+R - Refresh (alternative)
        SingleActivator(LogicalKeyboardKey.keyR, control: true):
            RefreshIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          NewSessionIntent: CallbackAction<NewSessionIntent>(
            onInvoke: (_) {
              _showNewSessionDialog(context);
              return null;
            },
          ),
          OpenTerminalIntent: CallbackAction<OpenTerminalIntent>(
            onInvoke: (_) {
              _toggleTerminal(context, activeSession);
              return null;
            },
          ),
          RefreshIntent: CallbackAction<RefreshIntent>(
            onInvoke: (_) {
              if (activeSession != null) {
                appState.refreshGitChanges(activeSession.id);
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: LayoutBuilder(
              builder: (context, constraints) {
                // Hide right sidebar if window is narrow (50% or less of a typical screen)
                final showRightSidebar = constraints.maxWidth > 1000;

                return Row(
                  children: [
                    // Left sidebar - sessions
                    SizedBox(
                      width: 250,
                      child: Sidebar(
                        onNewSession: () => _showNewSessionDialog(context),
                        onSettings: () => _showSettingsDialog(context),
                      ),
                    ),
                    // Main content - chat
                    Expanded(
                      child: activeSession != null
                          ? ChatPane(session: activeSession)
                          : const EmptyState(),
                    ),
                    // Right sidebar - git changes (only when session active and enough space)
                    if (activeSession != null && showRightSidebar)
                      ChangesSidebar(
                        summary: appState.getGitChanges(activeSession.id),
                        onRefresh: () =>
                            appState.refreshGitChanges(activeSession.id),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _toggleTerminal(BuildContext context, Session? activeSession) {
    if (activeSession == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active session')),
      );
      return;
    }

    context.read<AppState>().toggleTerminal(activeSession.id);
  }

  void _showNewSessionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => NewSessionDialog(
        onCreate: ({
          required String name,
          required String repoPath,
          required AgentType agentType,
        }) async {
          await context.read<AppState>().createSession(
                name: name,
                repoPath: repoPath,
                agentType: agentType,
              );
        },
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    final settings = context.read<AppState>().settings;
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(
        initialSettings: settings,
        onSave: (newSettings) =>
            context.read<AppState>().updateSettings(newSettings),
      ),
    );
  }
}

/// Chat pane showing conversation with agent, with sliding terminal overlay
class ChatPane extends StatelessWidget {
  final Session session;

  const ChatPane({required this.session, super.key});

  static const _animationDuration = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final chatSession = appState.getChatSession(session.id);
    final isTerminalOpen = appState.isTerminalOpen(session.id);

    return Column(
      children: [
        // Header bar
        _SessionHeader(session: session),
        // Chat view with terminal overlay
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fullWidth = constraints.maxWidth;

              return Stack(
                children: [
                  // Chat view (always present)
                  Positioned.fill(
                    child: ChatView(
                      messages: chatSession?.messages ?? [],
                      isAgentTyping: chatSession?.isAgentTyping ?? false,
                      agentType: session.agentType,
                      onSendMessage: (message) {
                        appState.sendMessage(session.id, message);
                      },
                      onStop: () {
                        appState.stopAgent(session.id);
                      },
                    ),
                  ),
                  // Sliding terminal panel from right - covers full width
                  AnimatedPositioned(
                    duration: _animationDuration,
                    curve: Curves.easeInOut,
                    top: 0,
                    bottom: 0,
                    right: isTerminalOpen ? 0 : -fullWidth,
                    width: fullWidth,
                    child: isTerminalOpen
                        ? TerminalPanel(
                            workingDirectory: session.worktreePath,
                            onClose: () => appState.closeTerminal(session.id),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Session header showing agent info and status
class _SessionHeader extends StatelessWidget {
  final Session session;

  const _SessionHeader({required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();
    final chatSession = appState.getChatSession(session.id);
    final isThinking = chatSession?.isAgentTyping ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Agent icon
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.secondaryContainer,
            child: SvgPicture.asset(
              Branding.appIconPath,
              width: 18,
              height: 18,
              colorFilter: const ColorFilter.mode(
                Branding.primaryColor,
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Session info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${session.agentType.name} • ${_formatPath(session.repoPath)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          // Status badge
          _StatusBadge(status: session.status, isThinking: isThinking),
          const SizedBox(width: 8),
          // Actions
          _SessionActions(session: session),
        ],
      ),
    );
  }

  String _formatPath(String path) {
    final parts = path.split('/');
    if (parts.length > 2) {
      return '.../${parts.sublist(parts.length - 2).join('/')}';
    }
    return path;
  }
}

/// Session action buttons
class _SessionActions extends StatelessWidget {
  final Session session;

  const _SessionActions({required this.session});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isTerminalOpen = appState.isTerminalOpen(session.id);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Terminal toggle button
        IconButton(
          icon: Icon(
            Icons.terminal,
            color: isTerminalOpen ? Branding.primaryColor : null,
          ),
          tooltip: isTerminalOpen
              ? 'Close Terminal (Ctrl+`)'
              : 'Open Terminal (Ctrl+`)',
          onPressed: () => appState.toggleTerminal(session.id),
        ),
        // Open in IDE button
        IconButton(
          icon: const Icon(Icons.code),
          tooltip: 'Open in IDE',
          onPressed: () {
            // TODO: Open worktree in VS Code / Cursor
          },
        ),
        // Restart agent
        if (session.status == SessionStatus.idle ||
            session.status == SessionStatus.error)
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Restart agent',
            onPressed: () => appState.restartAgent(session.id),
          ),
        // More menu
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            switch (value) {
              case 'diff':
                // TODO: Show diff viewer
                break;
              case 'close':
                appState.closeSession(session.id);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'diff',
              child: ListTile(
                leading: Icon(Icons.difference),
                title: Text('View Diff'),
                dense: true,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'close',
              child: ListTile(
                leading: Icon(Icons.close, color: Colors.red),
                title:
                    Text('Close Session', style: TextStyle(color: Colors.red)),
                dense: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final SessionStatus status;
  final bool isThinking;

  const _StatusBadge({required this.status, this.isThinking = false});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    if (isThinking && status != SessionStatus.error) {
      color = Branding.primaryColor;
      label = 'Thinking';
      icon = Icons.auto_awesome;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    switch (status) {
      case SessionStatus.running:
        color = Colors.green;
        label = 'Running';
        icon = Icons.play_circle;
        break;
      case SessionStatus.starting:
        color = Colors.orange;
        label = 'Starting';
        icon = Icons.pending;
        break;
      case SessionStatus.idle:
        color = Colors.grey;
        label = 'Idle';
        icon = Icons.pause_circle;
        break;
      case SessionStatus.error:
        color = Colors.red;
        label = 'Error';
        icon = Icons.error;
        break;
      case SessionStatus.terminated:
        color = Colors.grey;
        label = 'Stopped';
        icon = Icons.stop_circle;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            Branding.appIconPath,
            width: 64,
            height: 64,
            colorFilter: ColorFilter.mode(
              Theme.of(context).colorScheme.outline,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No active sessions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Click "New session" in the sidebar to start',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}
