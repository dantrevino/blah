import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/session.dart';
import '../../state/app_state.dart';
import '../session/new_session_dialog.dart';
import '../settings/settings_dialog.dart';
import '../terminal/terminal_view.dart';
import 'sidebar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final activeSession = appState.activeSession;

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 250,
            child: Sidebar(
              onNewSession: () => _showNewSessionDialog(context),
              onSettings: () => _showSettingsDialog(context),
            ),
          ),
          Expanded(
            child: activeSession != null
                ? TerminalPane(sessionId: activeSession.id)
                : const EmptyState(),
          ),
        ],
      ),
    );
  }

  void _showNewSessionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => NewSessionDialog(
        onCreate: ({
          required String repoPath,
          required agentType,
          required String instructions,
        }) {
          context.read<AppState>().createSession(
                repoPath: repoPath,
                agentType: agentType,
                instructions: instructions,
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
        onSave: (newSettings) {
          // TODO: Wire up settings save
        },
      ),
    );
  }
}

class TerminalPane extends StatelessWidget {
  final String sessionId;

  const TerminalPane({required this.sessionId, super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final session = appState.sessions.cast<Session?>().firstWhere(
          (s) => s?.id == sessionId,
          orElse: () => null,
        );
    final terminal = appState.getTerminal(sessionId);

    if (session == null || terminal == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Row(
            children: [
              Icon(_getAgentIcon(session.agentType), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  session.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _StatusBadge(status: session.status),
            ],
          ),
        ),
        Expanded(
          child: BlahTerminalView(
            terminal: terminal,
            onOutput: (output) {
              // Wire up output to session manager if needed
            },
          ),
        ),
      ],
    );
  }

  IconData _getAgentIcon(AgentType type) {
    switch (type) {
      case AgentType.claude:
        return Icons.smart_toy;
      case AgentType.codex:
        return Icons.code;
      case AgentType.opencode:
        return Icons.terminal;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final SessionStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case SessionStatus.running:
        color = Colors.green;
        label = 'Running';
        break;
      case SessionStatus.starting:
        color = Colors.orange;
        label = 'Starting';
        break;
      case SessionStatus.idle:
        color = Colors.grey;
        label = 'Idle';
        break;
      case SessionStatus.error:
        color = Colors.red;
        label = 'Error';
        break;
      case SessionStatus.terminated:
        color = Colors.grey;
        label = 'Terminated';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12),
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
          Icon(
            Icons.terminal,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No active sessions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Click + in the sidebar to create a new session',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
