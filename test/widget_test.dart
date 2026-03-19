import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riot/models/session.dart';
import 'package:riot/ui/chat/chat_view.dart';
import 'package:riot/ui/session/new_session_dialog.dart';

void main() {
  testWidgets('new session dialog does not show instructions field',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NewSessionDialog(
            onCreate: ({
              required name,
              required repoPath,
              required agentType,
            }) async {},
          ),
        ),
      ),
    );

    expect(find.text('Session Name'), findsOneWidget);
    expect(find.text('Repository Path'), findsOneWidget);
    expect(find.text('Coding Agent'), findsOneWidget);
    expect(find.text('Instructions'), findsNothing);
  });

  testWidgets('chat shows thinking feedback when waiting on empty thread',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatView(
            messages: const [],
            isAgentTyping: true,
            agentType: AgentType.claude,
            onSendMessage: (_) {},
          ),
        ),
      ),
    );

    expect(find.textContaining('thinking', findRichText: true), findsOneWidget);
  });
}
