import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/session_store.dart';
import 'services/settings_store.dart';
import 'services/session_manager.dart';
import 'state/app_state.dart';
import 'state/settings_state.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sessionStore = SessionStore();
  final settingsStore = SettingsStore();
  final sessionManager = SessionManager();
  final settingsState = SettingsState(settingsStore)..load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppState(sessionStore, sessionManager, settingsState),
        ),
        ChangeNotifierProvider.value(value: settingsState),
      ],
      child: const BlahApp(),
    ),
  );
}
