import 'dart:async';

import 'package:brigade_bridge/core/bridge_models.dart';
import 'package:brigade_bridge/daemon/codex_connector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_codex_server.dart';

BridgeTask _task({String target = 'codex:thr_1', String id = 'task-1'}) =>
    BridgeTask(
      id: id,
      sourceNodeId: 'user',
      targetNodeId: target,
      instruction: 'Do the requested work',
      projectId: 'project-one',
    );

void main() {
  group('CodexConnector.validateEndpoint', () {
    test('accepts loopback ws URLs and a safe thread ID', () {
      expect(
        CodexConnector.validateEndpoint(
          serverUrl: 'ws://127.0.0.1:4500',
          threadId: 'thr_abc',
        ).toString(),
        'ws://127.0.0.1:4500',
      );
      expect(
        CodexConnector.validateEndpoint(
          serverUrl: 'ws://[::1]:4500',
          threadId: 'thr_abc',
        ).host,
        '::1',
      );
    });

    test('rejects non-loopback, wrong scheme, credentials, paths, and ports',
        () {
      for (final url in [
        'http://127.0.0.1:4500',
        'wss://127.0.0.1:4500',
        'ws://example.com:4500',
        'ws://user:pass@127.0.0.1:4500',
        'ws://127.0.0.1:4500/base',
        'ws://127.0.0.1:4500?x=1',
        'ws://127.0.0.1:4500#frag',
        'ws://127.0.0.1',
        'ws://127.0.0.1:99999',
      ]) {
        expect(
          () => CodexConnector.validateEndpoint(
              serverUrl: url, threadId: 'thr_1'),
          throwsFormatException,
          reason: url,
        );
      }
    });

    test('rejects malformed thread IDs', () {
      for (final id in ['', 'a/b', r'a\b', 'a b', 'a\nb', 'x' * 257]) {
        expect(
          () => CodexConnector.validateEndpoint(
              serverUrl: 'ws://127.0.0.1:4500', threadId: id),
          throwsFormatException,
          reason: id,
        );
      }
    });
  });

  group('with a simulated app-server', () {
    late FakeCodexServer server;
    late CodexConnector connector;

    setUp(() async {
      server = await FakeCodexServer.start();
      connector = CodexConnector(
        serverUrl: server.url,
        threadId: 'thr_1',
        retryBaseDelay: const Duration(milliseconds: 5),
        turnTimeout: const Duration(seconds: 5),
      );
    });

    tearDown(() async {
      await connector.close();
      await server.close();
    });

    test('performs the handshake and resumes only the entered thread',
        () async {
      final node = await connector.connect();

      expect(node.id, 'codex:thr_1');
      expect(node.name, 'Codex');
      expect(node.adapterId, 'codex-app-server');
      expect(node.adapterVersion, 'codex-test/1.0');
      expect(node.capabilities, containsAll(['receive_task', 'cancel_task']));
      expect(node.capabilities, isNot(contains('sensitive_action_approval')));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final methods = server.received.map((m) => m['method']).toList();
      expect(methods,
          ['initialize', 'initialized', 'account/read', 'thread/resume']);
      // Never lists, starts, or forks threads and never logs in.
      expect(methods, isNot(contains('thread/list')));
      expect(methods, isNot(contains('thread/start')));
      expect(methods, isNot(contains('account/login/start')));
      final resume =
          server.received.last['params'] as Map<String, dynamic>;
      expect(resume['threadId'], 'thr_1');
    });

    test('rejects a server that is not signed in', () async {
      server.account = null;
      await expectLater(connector.connect(), throwsStateError);
    });

    test('allows a provider that needs no OpenAI sign-in', () async {
      server.account = null;
      server.requiresOpenaiAuth = false;
      expect((await connector.connect()).health, 'connected');
    });

    test('rejects an unknown thread', () async {
      server.knownThread = 'other';
      await expectLater(
        connector.connect(),
        throwsA(isA<CodexRpcException>()),
      );
    });

    test('returns the final answer and sends the task with project context',
        () async {
      server.onTurnStart = (s, _) {
        s.agentMessage('thinking out loud', phase: 'commentary');
        s.agentMessage('The final answer',
            phase: 'final_answer', id: 'item_2');
        s.turnCompleted('completed');
      };
      await connector.connect();

      final result = await connector.sendTask(_task());
      expect(result, 'The final answer');

      final start = server.received
          .firstWhere((m) => m['method'] == 'turn/start')['params'] as Map;
      expect(start['threadId'], 'thr_1');
      final text = ((start['input'] as List).single as Map)['text'] as String;
      expect(text, contains('projectId: project-one'));
      expect(text, contains('Do the requested work'));
    });

    test('uses the last agent message when no phase is reported', () async {
      server.onTurnStart = (s, _) {
        s.agentMessage('first', id: 'a');
        s.agentMessage('second', id: 'b');
        s.turnCompleted('completed');
      };
      await connector.connect();
      expect(await connector.sendTask(_task()), 'second');
    });

    test('fails a failed turn with its message', () async {
      server.onTurnStart =
          (s, _) => s.turnCompleted('failed', errorMessage: 'usage limit');
      await connector.connect();
      await expectLater(
        connector.sendTask(_task()),
        throwsA(predicate((e) => e.toString().contains('usage limit'))),
      );
    });

    test('fails when the turn completes with no assistant text', () async {
      server.onTurnStart = (s, _) => s.turnCompleted('completed');
      await connector.connect();
      await expectLater(
          connector.sendTask(_task()), throwsFormatException);
    });

    test('declines command, file, and permission approvals automatically',
        () async {
      final notices = <String>[];
      final noisy = CodexConnector(
        serverUrl: server.url,
        threadId: 'thr_1',
        onNotice: notices.add,
        turnTimeout: const Duration(seconds: 5),
      );
      addTearDown(noisy.close);
      server.onTurnStart = (s, _) {
        s.send({
          'method': 'item/commandExecution/requestApproval',
          'id': 900,
          'params': {'threadId': 'thr_1', 'turnId': 'turn_1', 'itemId': 'c1'},
        });
        s.send({
          'method': 'item/fileChange/requestApproval',
          'id': 901,
          'params': {'threadId': 'thr_1', 'turnId': 'turn_1', 'itemId': 'f1'},
        });
        s.send({
          'method': 'item/permissions/requestApproval',
          'id': 902,
          'params': {'threadId': 'thr_1', 'turnId': 'turn_1', 'itemId': 'p1'},
        });
        s.send({
          'method': 'item/tool/requestUserInput',
          'id': 903,
          'params': {'threadId': 'thr_1', 'turnId': 'turn_1'},
        });
        Timer(const Duration(milliseconds: 50), () {
          s.agentMessage('done', phase: 'final_answer');
          s.turnCompleted('completed');
        });
      };
      await noisy.connect();
      expect(await noisy.sendTask(_task()), 'done');

      final byId = {for (final r in server.responsesFromClient) r['id']: r};
      expect((byId[900]!['result'] as Map)['decision'], 'decline');
      expect((byId[901]!['result'] as Map)['decision'], 'decline');
      expect(byId[902]!['result'], {'permissions': {}});
      expect((byId[903]!['error'] as Map)['code'], -32601);
      expect(notices, hasLength(3));
    });

    test('mentions declined approvals when the turn then fails', () async {
      server.onTurnStart = (s, _) {
        s.send({
          'method': 'item/commandExecution/requestApproval',
          'id': 910,
          'params': {'threadId': 'thr_1', 'turnId': 'turn_1'},
        });
        Timer(const Duration(milliseconds: 50),
            () => s.turnCompleted('failed', errorMessage: 'blocked'));
      };
      await connector.connect();
      await expectLater(
        connector.sendTask(_task()),
        throwsA(predicate((e) => e.toString().contains('approve actions'))),
      );
    });

    test('rejects a second task while one is active', () async {
      server.onTurnStart = (s, _) {}; // never completes
      await connector.connect();
      final first = connector.sendTask(_task());
      unawaited(first.then((_) {}, onError: (_) {}));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await expectLater(
        connector.sendTask(_task(id: 'task-2')),
        throwsA(isA<CodexSessionBusyException>()),
      );
      await connector.cancelTask('task-1');
      await expectLater(first, throwsStateError);
    });

    test('cancelTask interrupts the active turn', () async {
      server.onTurnStart = (s, _) {};
      await connector.connect();
      final running = connector.sendTask(_task());
      unawaited(running.then((_) {}, onError: (_) {}));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await connector.cancelTask('task-1');
      await expectLater(
        running,
        throwsA(predicate((e) => e.toString().contains('interrupted'))),
      );
      final interrupt = server.received
          .firstWhere((m) => m['method'] == 'turn/interrupt')['params'] as Map;
      expect(interrupt, {'threadId': 'thr_1', 'turnId': 'turn_1'});
    });

    test('cancelTask for another task id does nothing', () async {
      server.onTurnStart = (s, _) {
        Timer(const Duration(milliseconds: 80), () {
          s.agentMessage('ok', phase: 'final_answer');
          s.turnCompleted('completed');
        });
      };
      await connector.connect();
      final running = connector.sendTask(_task());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await connector.cancelTask('different-task');
      expect(await running, 'ok');
      expect(server.received.map((m) => m['method']),
          isNot(contains('turn/interrupt')));
    });

    test('retries an overloaded turn/start with backoff', () async {
      server.overloadFirstTurnStarts = 2;
      server.onTurnStart = (s, _) {
        s.agentMessage('after retry', phase: 'final_answer');
        s.turnCompleted('completed');
      };
      await connector.connect();
      expect(await connector.sendTask(_task()), 'after retry');
      expect(
        server.received.where((m) => m['method'] == 'turn/start'),
        hasLength(3),
      );
    });

    test('rejects tasks addressed to another thread', () async {
      await connector.connect();
      expect(
        () => connector.sendTask(_task(target: 'codex:other')),
        throwsArgumentError,
      );
    });

    test('rejects tasks before connect', () async {
      expect(() => connector.sendTask(_task()), throwsStateError);
    });

    test('fails the active task and completes `closed` on disconnect',
        () async {
      server.onTurnStart = (s, _) {};
      await connector.connect();
      final running = connector.sendTask(_task());
      unawaited(running.then((_) {}, onError: (_) {}));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await server.socket!.close();
      await expectLater(running, throwsStateError);
      await connector.closed.timeout(const Duration(seconds: 2));
    });
  });
}
