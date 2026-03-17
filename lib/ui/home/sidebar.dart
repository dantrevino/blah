import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../session/session_card.dart';

class Sidebar extends StatelessWidget {
  final VoidCallback onNewSession;
  final VoidCallback onSettings;

  const Sidebar({
    required this.onNewSession,
    required this.onSettings,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final sessions = appState.sessions;

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(
                  'blah',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: onNewSession,
                  tooltip: 'New session',
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: sessions.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No sessions\n\nClick + to create'),
                    ),
                  )
                : ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return SessionCard(
                        session: session,
                        isActive: appState.activeSession?.id == session.id,
                        onTap: () => appState.setActiveSession(session.id),
                        onClose: () => appState.closeSession(session.id),
                      );
                    },
                  ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: onSettings,
                  tooltip: 'Settings',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
