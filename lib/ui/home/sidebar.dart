import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/session.dart';
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
                Expanded(
                  child: Tooltip(
                    message: 'New session (Ctrl+N)',
                    child: OutlinedButton.icon(
                      onPressed: onNewSession,
                      icon: const Icon(Icons.add),
                      label: const Text('New session'),
                    ),
                  ),
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
                        onLongPress: () =>
                            _showRenameDialog(context, appState, session),
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

  void _showRenameDialog(
    BuildContext context,
    AppState appState,
    Session session,
  ) {
    final controller = TextEditingController(text: session.name);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename Session'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Session Name',
          ),
          onSubmitted: (value) async {
            await appState.renameSession(session.id, value);
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await appState.renameSession(
                session.id,
                controller.text,
              );
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
