import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ops/in_memory_ops_logger.dart';
import 'ops/ops_coordinator.dart';
import 'services/chat_store.dart';
import 'services/session_store.dart';
import 'services/settings_store.dart';
import 'services/agent_driver.dart';
import 'state/app_state.dart';
import 'state/settings_state.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sessionStore = SessionStore();
  final chatStore = ChatStore();
  final settingsStore = SettingsStore();
  final driverManager = AgentDriverManager();
  final opsLogger = InMemoryOpsLogger();
  final opsCoordinator = OpsCoordinator(logger: opsLogger);
  final settingsState = SettingsState(settingsStore)..load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppState(
            sessionStore,
            chatStore,
            driverManager,
            opsCoordinator,
            opsLogger,
            settingsState,
          ),
        ),
        ChangeNotifierProvider.value(value: settingsState),
      ],
      child: const RiotApp(),
    ),
  );
}
