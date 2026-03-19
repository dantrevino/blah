import 'package:flutter/material.dart';
import '../../models/settings.dart';

class SettingsDialog extends StatefulWidget {
  final Settings initialSettings;
  final void Function(Settings) onSave;

  const SettingsDialog({
    required this.initialSettings,
    required this.onSave,
    super.key,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AppSettings _appSettings;
  late TerminalSettings _terminalSettings;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _appSettings = widget.initialSettings.app;
    _terminalSettings = widget.initialSettings.terminal;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave(Settings(
      app: _appSettings,
      terminal: _terminalSettings,
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'General'),
                Tab(text: 'Terminal'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _AppSettingsTab(
                    settings: _appSettings,
                    onChanged: (settings) =>
                        setState(() => _appSettings = settings),
                  ),
                  _TerminalSettingsTab(
                    settings: _terminalSettings,
                    onChanged: (settings) =>
                        setState(() => _terminalSettings = settings),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _AppSettingsTab extends StatelessWidget {
  final AppSettings settings;
  final void Function(AppSettings) onChanged;

  const _AppSettingsTab({
    required this.settings,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Branch Prefix',
              helperText: 'Prefix for agent worktree branches',
            ),
            controller: TextEditingController(text: settings.branchPrefix),
            onChanged: (value) =>
                onChanged(settings.copyWith(branchPrefix: value)),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Auto-cleanup Worktrees'),
            subtitle: const Text('Delete worktrees when sessions close'),
            value: settings.autoCleanupWorktrees,
            onChanged: (value) =>
                onChanged(settings.copyWith(autoCleanupWorktrees: value)),
          ),
          SwitchListTile(
            title: const Text('Confirm on Close'),
            subtitle: const Text('Ask before closing session'),
            value: settings.confirmOnClose,
            onChanged: (value) =>
                onChanged(settings.copyWith(confirmOnClose: value)),
          ),
          SwitchListTile(
            title: const Text('Debug Mode'),
            subtitle: const Text('Show exact agent command line in chat'),
            value: settings.debugMode,
            onChanged: (value) =>
                onChanged(settings.copyWith(debugMode: value)),
          ),
        ],
      ),
    );
  }
}

class _TerminalSettingsTab extends StatelessWidget {
  final TerminalSettings settings;
  final void Function(TerminalSettings) onChanged;

  const _TerminalSettingsTab({
    required this.settings,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: settings.fontFamily,
            decoration: const InputDecoration(labelText: 'Font Family'),
            items: ['JetBrainsMono Nerd Font', 'FiraCode Nerd Font']
                .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                onChanged(settings.copyWith(fontFamily: value));
              }
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(labelText: 'Font Size'),
                  keyboardType: TextInputType.number,
                  controller:
                      TextEditingController(text: settings.fontSize.toString()),
                  onChanged: (value) {
                    final size = double.tryParse(value) ?? 14;
                    onChanged(settings.copyWith(fontSize: size));
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: settings.themeName,
                  decoration: const InputDecoration(labelText: 'Theme'),
                  items: ['dark', 'light', 'dracula']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      onChanged(settings.copyWith(themeName: value));
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Enable Ligatures'),
            subtitle: const Text('Requires font with ligature support'),
            value: settings.ligaturesEnabled,
            onChanged: (value) =>
                onChanged(settings.copyWith(ligaturesEnabled: value)),
          ),
          SwitchListTile(
            title: const Text('Cursor Blink'),
            value: settings.cursorBlink,
            onChanged: (value) =>
                onChanged(settings.copyWith(cursorBlink: value)),
          ),
        ],
      ),
    );
  }
}
