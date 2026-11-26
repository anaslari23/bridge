import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:brigade_bridge/core/bridge_models.dart';
import 'package:brigade_bridge/daemon/antigravity_connector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_agy.dart';

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
  late String agy;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fake-agy-');
    agy = await writeFakeAgy(dir);
  });

  tearDown(() => dir.delete(recursive: true));

  List<String> log(String name) {
    final file = File('${dir.path}/$name');
    return file.existsSync() ? file.readAsLinesSync() : <String>[];
  }

  group('validateConfig', () {
    test('accepts an existing absolute directory and a safe conversation ID',
        () {
      expect(
        AntigravityConnector.validateConfig(
            workingDirectory: dir.path, conversationId: '055a398f-db14-4c5f'),
        '055a398f-db14-4c5f',
      );
      expect(
        AntigravityConnector.validateConfig(workingDirectory: dir.path),
        isNull,
      );
    });

    test('rejects relative, missing, and malformed input', () {
      for (final bad in ['', 'relative/dir', '/definitely/not/here/xyz']) {
        expect(
          () => AntigravityConnector.validateConfig(workingDirectory: bad),
          throwsFormatException,
          reason: bad,
        );
      }
      for (final id in ['a b', 'a/b', r'a;b', '--flag value', 'x' * 129]) {
        expect(
          () => AntigravityConnector.validateConfig(
              workingDirectory: dir.path, conversationId: id),
          throwsFormatException,
          reason: id,
        );
      }
    });
  });

  test('connect reports a missing CLI clearly', () async {
    final connector = AntigravityConnector(
        workingDirectory: dir.path, executable: '${dir.path}/nope');
    await expectLater(
      connector.connect(),
      throwsA(predicate((e) => e.toString().contains('not found'))),
    );
  });

  test('connect fails when the CLI is not signed in', () async {
    File('${dir.path}/models_fail').writeAsStringSync('');
    final connector =
        AntigravityConnector(workingDirectory: dir.path, executable: agy);
    await expectLater(
      connector.connect(),
      throwsA(predicate((e) =>
          e.toString().contains('authentication required') &&
          e.toString().contains('Sign in'))),
    );
  });

  test('connect only runs the read-only models command and sends no prompt',
      () async {
    final connector =
        AntigravityConnector(workingDirectory: dir.path, executable: agy);
    final node = await connector.connect();
    expect(node.id, 'antigravity:new');
    expect(node.name, 'Antigravity');
    expect(node.adapterId, 'antigravity-cli');
    expect(node.capabilities, containsAll(['receive_task', 'cancel_task']));
    expect(log('args.log'), isEmpty);
  });

  test('runs a task via stdin, never auto-approves, and reuses the conversation',
      () async {
    final connector =
        AntigravityConnector(workingDirectory: dir.path, executable: agy);
    final node = await connector.connect();

    expect(await connector.sendTask(_task(node.id, 'First request')),
        'Antigravity answer');
    expect(connector.conversationId, 'c-new-123');
    expect(node.id, 'antigravity:new'); // node identity is stable

    expect(await connector.sendTask(_task(node.id, 'Second', id: 'task-2')),
        'Antigravity answer');

    final args = log('args.log');
    expect(args, hasLength(2));
    expect(args[0], isNot(contains('--conversation')));
    expect(args[1], contains('--conversation c-new-123'));
    for (final line in args) {
      expect(line, contains('--input-format stream-json'));
      expect(line, contains('--output-format stream-json'));
      expect(line, isNot(contains('dangerously')));
      expect(line, isNot(contains('First request'))); // prompt not in argv
    }
    final stdin = log('stdin.log').first;
    expect(stdin, contains('projectId: project-one'));
    expect(stdin, contains('First request'));
    expect(log('cwd.log').first, endsWith(dir.path.split('/').last));
  });

  test('resumes a user-supplied conversation from the first task', () async {
    final connector = AntigravityConnector(
      workingDirectory: dir.path,
      conversationId: 'chosen-conv',
      executable: agy,
    );
    final node = await connector.connect();
    expect(node.id, 'antigravity:chosen-conv');
    await connector.sendTask(_task(node.id, 'Hi'));
    expect(log('args.log').single, contains('--conversation chosen-conv'));
  });

  test('falls back to streamed text when the result has no response',
      () async {
    final connector =
        AntigravityConnector(workingDirectory: dir.path, executable: agy);
    final node = await connector.connect();
    expect(await connector.sendTask(_task(node.id, 'DELTAS please')),
        'Hello world');
  });

  test('surfaces the error status and message from the result', () async {
    final connector =
        AntigravityConnector(workingDirectory: dir.path, executable: agy);
    final node = await connector.connect();
    await expectLater(
      connector.sendTask(_task(node.id, 'FAIL now')),
      throwsA(predicate((e) =>
          e.toString().contains('ERROR') &&
          e.toString().contains('model unavailable'))),
    );
  });

  test('fails with the exit code and stderr when no result is produced',
      () async {
    final connector =
        AntigravityConnector(workingDirectory: dir.path, executable: agy);
    final node = await connector.connect();
    await expectLater(
      connector.sendTask(_task(node.id, 'CRASH now')),
      throwsA(predicate((e) =>
          e.toString().contains('code 3') && e.toString().contains('boom'))),
    );
  });

  test('forwards Antigravity permission notices without approving anything',
      () async {
    final notices = <String>[];
    final connector = AntigravityConnector(
        workingDirectory: dir.path, executable: agy, onNotice: notices.add);
    final node = await connector.connect();
    await connector.sendTask(_task(node.id, 'NOTICE run something'));
    expect(notices.single, contains('run_command was denied'));
  });

  test('rejects a second task while one is running, then cancel interrupts',
      () async {
    final connector =
        AntigravityConnector(workingDirectory: dir.path, executable: agy);
    final node = await connector.connect();
    final running = connector.sendTask(_task(node.id, 'HOLD this'));
    unawaited(running.then((_) {}, onError: (_) {}));
    await Future<void>.delayed(const Duration(milliseconds: 500));

    await expectLater(
      connector.sendTask(_task(node.id, 'other', id: 'task-2')),
      throwsA(isA<AntigravitySessionBusyException>()),
    );
    await connector.cancelTask('task-1');
    await expectLater(
      running,
      throwsA(predicate((e) => e.toString().contains('canceled'))),
    );
  });

  test('cancelTask for another task id leaves the run alone', () async {
    final connector =
        AntigravityConnector(workingDirectory: dir.path, executable: agy);
    final node = await connector.connect();
    final running = connector.sendTask(_task(node.id, 'normal'));
    await connector.cancelTask('different');
    expect(await running, 'Antigravity answer');
  });

  test('rejects tasks addressed elsewhere or sent before connect', () async {
    final connector =
        AntigravityConnector(workingDirectory: dir.path, executable: agy);
    expect(() => connector.sendTask(_task('antigravity:new', 'x')),
        throwsStateError);
    await connector.connect();
    expect(() => connector.sendTask(_task('antigravity:other', 'x')),
        throwsArgumentError);
  });

  test('a stdout line that is not JSON is ignored', () async {
    final connector =
        AntigravityConnector(workingDirectory: dir.path, executable: agy);
    final node = await connector.connect();
    // The default fake path prints a garbage line before the result.
    expect(await connector.sendTask(_task(node.id, 'plain')),
        'Antigravity answer');
    expect(jsonDecode(log('stdin.log').first), isA<Map>());
  });
}
