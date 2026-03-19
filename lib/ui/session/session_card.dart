import 'package:flutter/material.dart';
import '../../models/session.dart';

class SessionCard extends StatelessWidget {
  final Session session;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onClose;

  const SessionCard({
    required this.session,
    required this.isActive,
    required this.onTap,
    required this.onLongPress,
    required this.onClose,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive
          ? Theme.of(context).colorScheme.primaryContainer
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _buildStatusIndicator(),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: isActive ? FontWeight.bold : null,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _getAgentLabel(session.agentType),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: onClose,
                tooltip: 'Close session',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    Color color;
    switch (session.status) {
      case SessionStatus.running:
        color = Colors.green;
        break;
      case SessionStatus.starting:
        color = Colors.orange;
        break;
      case SessionStatus.error:
        color = Colors.red;
        break;
      case SessionStatus.idle:
        color = Colors.grey;
        break;
      case SessionStatus.terminated:
        color = Colors.grey;
        break;
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  String _getAgentLabel(AgentType type) {
    switch (type) {
      case AgentType.claude:
        return 'Claude';
      case AgentType.codex:
        return 'Codex';
      case AgentType.opencode:
        return 'OpenCode';
    }
  }
}
