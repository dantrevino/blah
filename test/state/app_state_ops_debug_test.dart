import 'package:flutter_test/flutter_test.dart';
import 'package:riot/models/chat.dart';
import 'package:riot/models/session.dart';
import 'package:riot/models/settings.dart';
import 'package:riot/ops/in_memory_ops_logger.dart';
import 'package:riot/ops/ops_coordinator.dart';
import 'package:riot/services/agent_driver.dart';
import 'package:riot/services/chat_store.dart';
import 'package:riot/services/session_store.dart';
import 'package:riot/services/settings_store.dart';
import 'package:riot/state/app_state.dart';
import 'package:riot/state/settings_state.dart';

class _FakeSessionStore extends SessionStore {
  _FakeSessionStore(this._sessions);

  final List<Session> _sessions;

  @override
  Future<List<Session>> loadAll() async => _sessions;

  @override
  Future<void> save(Session session) async {}

  @override
  Future<void> delete(String sessionId) async {}
}

class _FakeChatStore extends ChatStore {
  @override
  Future<Map<String, ChatSession>> loadAll(List<String> sessionIds) async => {};

  @override
  Future<void> save(ChatSession chat) async {}

  @override
  Future<void> delete(String sessionId) async {}
}

class _FakeSettingsStore extends SettingsStore {
  _FakeSettingsStore(this._settings);

  final Settings _settings;

  @override
  Future<Settings> load() async => _settings;

  @override
  Future<void> save(Settings settings) async {}
}

class _Harness {
  _Harness(this.appState, this.opsLogger);

  final AppState appState;
  final InMemoryOpsLogger opsLogger;
}

void main() {
  Session sessionFor(String id) => Session(
        id: id,
        number: 1,
        name: 'Debug Session',
        repoPath: '/tmp/repo',
        worktreePath: '/tmp/repo/.riot/worktrees/agent/$id',
        gitBranch: 'agent/$id',
        agentType: AgentType.claude,
        status: SessionStatus.running,
      );

  Future<_Harness> buildAppState({required bool debugMode}) async {
    final settings = Settings(
      app: AppSettings.defaults().copyWith(debugMode: debugMode),
    );
    final settingsState = SettingsState(_FakeSettingsStore(settings));
    await settingsState.load();

    final opsLogger = InMemoryOpsLogger();
    final appState = AppState(
      _FakeSessionStore([sessionFor('s-ops')]),
      _FakeChatStore(),
      AgentDriverManager(),
      OpsCoordinator(logger: opsLogger),
      opsLogger,
      settingsState,
    );
    while (appState.getChatSession('s-ops') == null) {
      await Future<void>.delayed(Duration.zero);
    }
    return _Harness(appState, opsLogger);
  }

  test('failed operation appends debug system message when debug mode on',
      () async {
    final harness = await buildAppState(debugMode: true);
    final chat = harness.appState.getChatSession('s-ops');
    expect(chat, isNotNull);

    final coordinator = OpsCoordinator(logger: harness.opsLogger);
    await coordinator.sendMessageFlow<void>(
      sessionId: 's-ops',
      execute: () async {
        throw Exception('boom');
      },
    );
    await Future<void>.delayed(Duration.zero);

    final updatedChat = harness.appState.getChatSession('s-ops');
    expect(updatedChat, isNotNull);
    expect(updatedChat!.messages.isNotEmpty, isTrue);
    final message = updatedChat.messages.last;
    expect(message.role, MessageRole.system);
    expect(message.content, contains('ops failed [sendMessage]'));
    expect(message.content, contains('id='));
    expect(message.content, contains('boom'));

    harness.appState.dispose();
  });

  test('failed operation does not append debug message when debug mode off',
      () async {
    final harness = await buildAppState(debugMode: false);

    await OpsCoordinator(logger: harness.opsLogger).sendMessageFlow<void>(
      sessionId: 's-ops',
      execute: () async {
        throw Exception('boom');
      },
    );
    await Future<void>.delayed(Duration.zero);

    final chat = harness.appState.getChatSession('s-ops');
    expect(chat, isNotNull);
    expect(chat!.messages, isEmpty);

    harness.appState.dispose();
  });
}
