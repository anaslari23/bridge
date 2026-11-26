import 'dart:async';
import 'dart:io';

import 'package:brigade_bridge/core/bridge_models.dart';
import 'package:brigade_bridge/daemon/claude_code_connector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_claude.dart';

BridgeTask _task(String node, String text, {String id = 'task-1'}) =>
    BridgeTask(
      id: id,
      sourceNodeId: 'user',
      targetNodeId: node,
      instruction: text,
      projectId: 'project-one',
    );

void main() {
  late Directory dir;
  late String claude;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fake-claude-');
    claude = await writeFakeClaude(dir);
  });
  tearDown(() => dir.delete(recursive: true));

  List<String> log(String name) {
    final file = File('${dir.path}/$name');
    return file.existsSync() ? file.readAsLinesSync() : <String>[];
  }

  ClaudeCodeConnector make({String? sessionId, void Function(String)? notice}) =>
      ClaudeCodeConnector(
        workingDirectory: dir.path,
        sessionId: sessionId,
        executable: claude,
        onNotice: notice,
      );

  group('config', () {
    test('validates directory and session ID', () {
      expect(ClaudeCodeConnector.validateConfig(workingDirectory: dir.path),
          isNull);
      expect(
        ClaudeCodeConnector.validateConfig(
            workingDirectory: dir.path, sessionId: 'abc-123_X'),
        'abc-123_X',
      );
      for (final bad in ['', 'relative', '/definitely/not/here/xyz']) {
        expect(
          () => ClaudeCodeConnector.validateConfig(workingDirectory: bad),
          throwsFormatException,
          reason: bad,
        );
      }
      for (final id in ['a b', 'a/b', 'a;b', '--flag', '-x', 'x' * 129]) {
        expect(
          () => ClaudeCodeConnector.validateConfig(
              workingDirectory: dir.path, sessionId: id),
          throwsFormatException,
          reason: id,
        );
      }
    });

    test('removes API-key variables from the child environment', () {
      final cleaned = ClaudeCodeConnector.sanitizedEnvironment({
        'PATH': '/bin',
        'HOME': '/home/x',
        'ANTHROPIC_API_KEY': 'sk-secret',
        'ANTHROPIC_AUTH_TOKEN': 'tok',
        'CLAUDE_CODE_OAUTH_TOKEN': 'login-token',
      });
      expect(cleaned.keys,
          unorderedEquals(['PATH', 'HOME', 'CLAUDE_CODE_OAUTH_TOKEN']));
    });
  });

  group('connect', () {
    test('reports a missing CLI', () async {
      final connector = ClaudeCodeConnector(
          workingDirectory: dir.path, executable: '${dir.path}/nope');
      await expectLater(connector.connect(),
          throwsA(predicate((e) => e.toString().contains('not found'))));
    });

    test('requires a signed-in account', () async {
      File('${dir.path}/not_logged_in').writeAsStringSync('');
      await expectLater(
        make().connect(),
        throwsA(predicate((e) => e.toString().contains('not signed in'))),
      );
    });

    test('refuses an API-key login', () async {
      File('${dir.path}/api_key_auth').writeAsStringSync('');
      await expectLater(
        make().connect(),
        throwsA(predicate((e) => e.toString().contains('API key'))),
      );
    });

    test('registers a node and sends no prompt', () async {
      final node = await make().connect();
      expect(node.id, 'claude-code:new');
      expect(node.name, 'Claude Code');
      expect(node.adapterId, 'claude-code-cli');
      expect(node.adapterVersion, '9.9.9 (Claude Code)');
      expect(node.capabilities, containsAll(['receive_task', 'cancel_task']));
      expect(log('args.log'), isEmpty);
    });
  });

  group('tasks', () {
    test('runs via stdin without bypass flags and resumes the session',
        () async {
      final connector = make();
      final node = await connector.connect();

      expect(await connector.sendTask(_task(node.id, 'First request')),
          'Claude answer');
      expect(connector.sessionId, 'sess-new-1');
      expect(node.id, 'claude-code:new');
      expect(await connector.sendTask(_task(node.id, 'Second', id: 'task-2')),
          'Claude answer');

      final args = log('args.log');
      expect(args, hasLength(2));
      expect(args[0], '-p --output-format stream-json --verbose');
      expect(args[1], contains('--resume sess-new-1'));
      for (final line in args) {
        expect(line, isNot(contains('dangerously')));
        expect(line, isNot(contains('--bare')));
        expect(line, isNot(contains('First request')));
      }
      expect(log('stdin.log').first, contains('projectId: project-one'));
      expect(log('stdin.log').first, contains('First request'));
      expect(log('env.log').first, 'KEY=unset TOKEN=unset');
    });

    test('resumes a user-supplied session from the first task', () async {
      final connector = make(sessionId: 'chosen');
      final node = await connector.connect();
      expect(node.id, 'claude-code:chosen');
      await connector.sendTask(_task(node.id, 'Hi'));
      expect(log('args.log').single, contains('--resume chosen'));
    });

    test('falls back to assistant text when the result is empty', () async {
      final connector = make();
      final node = await connector.connect();
      expect(await connector.sendTask(_task(node.id, 'ASSISTANT text')),
          'Streamed answer');
    });

    test('reports denied tool calls but still returns the answer', () async {
      final notices = <String>[];
      final connector = make(notice: notices.add);
      final node = await connector.connect();
      expect(await connector.sendTask(_task(node.id, 'DENY it')),
          'done without the command');
      expect(notices.single, contains('denied a tool call'));
      expect(notices.single, contains('(Bash)'));
    });

    test('surfaces an error result', () async {
      final connector = make();
      final node = await connector.connect();
      await expectLater(
        connector.sendTask(_task(node.id, 'FAIL now')),
        throwsA(predicate((e) =>
            e.toString().contains('error_during_execution') &&
            e.toString().contains('Invalid API key'))),
      );
    });

    test('fails with exit code and stderr when there is no result', () async {
      final connector = make();
      final node = await connector.connect();
      await expectLater(
        connector.sendTask(_task(node.id, 'CRASH now')),
        throwsA(predicate((e) =>
            e.toString().contains('code 3') && e.toString().contains('boom'))),
      );
    });

    test('rejects a second task while running; cancel interrupts', () async {
      final connector = make();
      final node = await connector.connect();
      final running = connector.sendTask(_task(node.id, 'HOLD this'));
      unawaited(running.then((_) {}, onError: (_) {}));
      await Future<void>.delayed(const Duration(milliseconds: 500));

      await expectLater(
        connector.sendTask(_task(node.id, 'other', id: 'task-2')),
        throwsA(isA<ClaudeCodeSessionBusyException>()),
      );
      await connector.cancelTask('task-1');
      await expectLater(running,
          throwsA(predicate((e) => e.toString().contains('canceled'))));
    });

    test('cancelTask for another id leaves the run alone', () async {
      final connector = make();
      final node = await connector.connect();
      final running = connector.sendTask(_task(node.id, 'normal'));
      await connector.cancelTask('different');
      expect(await running, 'Claude answer');
    });

    test('rejects wrong target and use before connect', () async {
      final connector = make();
      expect(() => connector.sendTask(_task('claude-code:new', 'x')),
          throwsStateError);
      await connector.connect();
      expect(() => connector.sendTask(_task('claude-code:other', 'x')),
          throwsArgumentError);
    });
  });
}
