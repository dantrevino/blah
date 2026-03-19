import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../../models/session.dart';
import '../../services/git_checker.dart';

class NewSessionDialog extends StatefulWidget {
  final Future<void> Function({
    required String name,
    required String repoPath,
    required AgentType agentType,
  }) onCreate;

  const NewSessionDialog({
    required this.onCreate,
    super.key,
  });

  @override
  State<NewSessionDialog> createState() => _NewSessionDialogState();
}

class _NewSessionDialogState extends State<NewSessionDialog> {
  final _nameController = TextEditingController();
  final _repoController = TextEditingController();
  AgentType _selectedAgent = AgentType.claude;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _repoController.dispose();
    super.dispose();
  }

  Future<void> _selectRepo() async {
    final directory = await getDirectoryPath();
    if (directory != null) {
      _repoController.text = directory;
      setState(() => _error = null);
    }
  }

  Future<void> _createSession() async {
    final name = _nameController.text.trim();
    final repoPath = _repoController.text.trim();

    if (repoPath.isEmpty) {
      setState(() => _error = 'Please select a repository');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await GitChecker.verifyRepo(repoPath);

      await widget.onCreate(
        name: name,
        repoPath: repoPath,
        agentType: _selectedAgent,
      );

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Session'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Session Name',
                hintText: 'e.g. Fix auth regression',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _repoController,
                    decoration: const InputDecoration(
                      labelText: 'Repository Path',
                      hintText: '/path/to/repo',
                    ),
                    readOnly: true,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.folder_open),
                  onPressed: _selectRepo,
                  tooltip: 'Browse',
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<AgentType>(
              initialValue: _selectedAgent,
              decoration: const InputDecoration(labelText: 'Coding Agent'),
              items: AgentType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_getAgentLabel(type)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedAgent = value);
                }
              },
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _createSession,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Start Session'),
        ),
      ],
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
