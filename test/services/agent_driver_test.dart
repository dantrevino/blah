import 'package:flutter_test/flutter_test.dart';
import 'package:riot/services/agent_driver.dart';

void main() {
  test('buildOpenCodeRunArgs starts first message without continue', () {
    final args = buildOpenCodeRunArgs(
      worktreePath: '/tmp/worktree',
      message: 'hello',
      hasExistingSession: false,
    );

    expect(
        args,
        containsAll(
            ['run', '--format', 'json', '--dir', '/tmp/worktree', 'hello']));
    expect(args, isNot(contains('--continue')));
  });

  test('buildOpenCodeRunArgs continues session for follow-up messages', () {
    final args = buildOpenCodeRunArgs(
      worktreePath: '/tmp/worktree',
      message: 'follow up',
      hasExistingSession: true,
    );

    expect(args, contains('--continue'));
    expect(args.last, 'follow up');
  });

  test('buildCodexExecArgs includes prompt argument', () {
    final args = buildCodexExecArgs(
      worktreePath: '/tmp/worktree',
      message: 'hello codex',
    );

    expect(
      args,
      containsAll(['exec', '--json', '--full-auto', '-C', '/tmp/worktree']),
    );
    expect(args.last, 'hello codex');
  });

  test('extractOpenCodeText reads text from part payload', () {
    final text = extractOpenCodeText({
      'type': 'text',
      'part': {'text': 'Hi from open code'}
    });
    expect(text, 'Hi from open code');
  });

  test('extractCodexText reads text from item.completed payload', () {
    final text = extractCodexText({
      'type': 'item.completed',
      'item': {'type': 'agent_message', 'text': 'Hi from codex'}
    });
    expect(text, 'Hi from codex');
  });
}
