import 'package:flutter/material.dart';
import '../models/settings.dart';
import '../services/settings_store.dart';

class SettingsState extends ChangeNotifier {
  final SettingsStore _store;
  Settings _settings;
  bool _loaded = false;

  SettingsState(this._store) : _settings = Settings();

  Settings get settings => _settings;
  bool get loaded => _loaded;

  Future<void> load() async {
    _settings = await _store.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> update(Settings settings) async {
    _settings = settings;
    await _store.save(settings);
    notifyListeners();
  }

  Future<void> updateApp(AppSettings app) async {
    _settings = _settings.copyWith(app: app);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> updateTerminal(TerminalSettings terminal) async {
    _settings = _settings.copyWith(terminal: terminal);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> updateAgents(AgentSettings agents) async {
    _settings = _settings.copyWith(agents: agents);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> reset() async {
    await _store.reset();
    _settings = Settings();
    notifyListeners();
  }
}
