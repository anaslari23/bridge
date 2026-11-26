import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:brigade_bridge/core/bridge_models.dart';
import 'package:brigade_bridge/daemon/opencode_connector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OpenCodeConnector.validateEndpoint', () {
    test('accepts loopback URLs and a single safe session segment', () {
      expect(
        OpenCodeConnector.validateEndpoint(
          serverUrl: 'http://127.0.0.1:4096',
          sessionId: 'ses_abc123',
        ).toString(),
        'http://127.0.0.1:4096',
      );
      expect(
        OpenCodeConnector.validateEndpoint(
          serverUrl: 'http://[::1]:4096',
          sessionId: 'session-1',
        ).host,
        '::1',
      );
    });

    test('rejects non-loopback, credentials, paths, query, and fragments', () {
      for (final url in [
        'https://127.0.0.1:4096',
        'http://example.com:4096',
        'http://user:pass@127.0.0.1:4096',
        'http://127.0.0.1:4096/base',
        'http://127.0.0.1:4096?x=1',
        'http://127.0.0.1:4096?',
        'http://127.0.0.1:4096#fragment',
        'http://127.0.0.1:4096#',
        'http://127.0.0.1',
        'http://127.0.0.1:99999',
      ]) {
        expect(
          () => OpenCodeConnector.validateEndpoint(
            serverUrl: url,
            sessionId: 'session-1',
          ),
          throwsFormatException,
          reason: url,
        );
      }
    });

    test('rejects malformed session IDs', () {
      for (final sessionId in [
        '',
        'has/slash',
        r'has\backslash',
        'has space',
        'has\nnewline',
        'x' * 257,
      ]) {
        expect(
          () => OpenCodeConnector.validateEndpoint(
            serverUrl: 'http://127.0.0.1:4096',
            sessionId: sessionId,
          ),
          throwsFormatException,
          reason: sessionId,
        );
      }
    });
  });

  test('connects only the entered session and returns its assistant text',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requests = <String>[];
    final requestBodies = <Map<String, dynamic>>[];
    server.listen((request) async {
      requests.add('${request.method} ${request.uri.path}');
      if (request.method == 'GET' && request.uri.path == '/global/health') {
        request.response
            .write(jsonEncode({'healthy': true, 'version': 'test'}));
      } else if (request.method == 'GET' &&
          request.uri.path == '/session/ses_abc123') {
        request.response
            .write(jsonEncode({'id': 'ses_abc123', 'title': 'Test'}));
      } else if (request.method == 'POST' &&
          request.uri.path == '/session/ses_abc123/message') {
        requestBodies.add(Map<String, dynamic>.from(
            jsonDecode(await utf8.decoder.bind(request).join()) as Map));
        request.response.write(jsonEncode({
          'info': {'id': 'assistant-1', 'role': 'assistant'},
          'parts': [
            {'type': 'text', 'text': 'OpenCode answer'},
          ],
        }));
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });

    final connector = OpenCodeConnector(
      serverUrl: 'http://127.0.0.1:${server.port}',
      sessionId: 'ses_abc123',
    );
    final node = await connector.connect();
    expect(node.id, 'opencode:ses_abc123');
    expect(node.capabilities, contains('receive_task'));
    expect(node.capabilities, isNot(contains('sensitive_action_approval')));

    final task = BridgeTask(
      id: 'bridge-task-1',
      sourceNodeId: 'user',
      targetNodeId: node.id,
      instruction: 'Do the requested work',
      projectId: 'project-one',
    );
    expect(await connector.sendTask(task), 'OpenCode answer');
    expect(
      await connector.sendTask(task, prompt: 'Follow-up prompt'),
      'OpenCode answer',
    );
    expect(requests, [
      'GET /global/health',
      'GET /session/ses_abc123',
      'POST /session/ses_abc123/message',
      'POST /session/ses_abc123/message',
    ]);
    expect(
      requestBodies.first['parts'],
      contains(predicate((part) =>
          part is Map &&
          part['type'] == 'text' &&
          (part['text'] as String).contains('Do the requested work'))),
    );
    expect(requestBodies.first.toString(), contains('projectId: project-one'));
    expect(requestBodies.first.toString(), isNot(contains('bridge-task-1')));
    expect(
      (requestBodies.last['parts'] as List).single['text'],
      contains('Follow-up prompt'),
    );
    await connector.close();
  });

  test('cancels only the active task in its explicitly paired session',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final abortPaths = <String>[];
    final reply = Completer<void>();
    server.listen((request) async {
      if (request.method == 'GET' && request.uri.path == '/global/health') {
        request.response
            .write(jsonEncode({'healthy': true, 'version': 'test'}));
      } else if (request.method == 'GET' &&
          request.uri.path == '/session/ses_active') {
        request.response.write(jsonEncode({'id': 'ses_active'}));
      } else if (request.method == 'POST' &&
          request.uri.path == '/session/ses_active/message') {
        await reply.future;
        request.response.write(jsonEncode({
          'info': {'role': 'assistant'},
          'parts': [
            {'type': 'text', 'text': 'Stopped'},
          ],
        }));
      } else if (request.method == 'POST' &&
          request.uri.path == '/session/ses_active/abort') {
        abortPaths.add(request.uri.path);
        reply.complete();
        request.response.write('true');
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });

    final connector = OpenCodeConnector(
      serverUrl: 'http://127.0.0.1:${server.port}',
      sessionId: 'ses_active',
    );
    await connector.connect();
    final task = BridgeTask(
      id: 'bridge-task-active',
      sourceNodeId: 'user',
      targetNodeId: 'opencode:ses_active',
      instruction: 'Long task',
    );
    final resultFuture = connector.sendTask(task);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await connector.cancelTask(task.id);
    expect(await resultFuture, 'Stopped');
    expect(abortPaths, ['/session/ses_active/abort']);
    await connector.close();
  });

  test('rejects overlapping work because abort is session-wide', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final started = Completer<void>();
    final abortPaths = <String>[];
    final reply = Completer<void>();
    server.listen((request) async {
      if (request.method == 'GET' && request.uri.path == '/global/health') {
        request.response
            .write(jsonEncode({'healthy': true, 'version': 'test'}));
      } else if (request.method == 'GET' &&
          request.uri.path == '/session/ses_concurrent') {
        request.response.write(jsonEncode({'id': 'ses_concurrent'}));
      } else if (request.method == 'POST' &&
          request.uri.path == '/session/ses_concurrent/message') {
        await utf8.decoder.bind(request).join();
        if (!started.isCompleted) started.complete();
        await reply.future;
        request.response.write(jsonEncode({
          'info': {'role': 'assistant'},
          'parts': [
            {'type': 'text', 'text': 'cancelled result'},
          ],
        }));
      } else if (request.method == 'POST' &&
          request.uri.path == '/session/ses_concurrent/abort') {
        abortPaths.add(request.uri.path);
        reply.complete();
        request.response.write('true');
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });

    final connector = OpenCodeConnector(
      serverUrl: 'http://127.0.0.1:${server.port}',
      sessionId: 'ses_concurrent',
    );
    final node = await connector.connect();
    final slowTask = BridgeTask(
      id: 'slow-task',
      sourceNodeId: 'user',
      targetNodeId: node.id,
      instruction: 'First task',
    );
    final fastTask = BridgeTask(
      id: 'fast-task',
      sourceNodeId: 'user',
      targetNodeId: node.id,
      instruction: 'Second task',
    );

    final firstResult = connector.sendTask(slowTask);
    await started.future;
    await expectLater(
      connector.sendTask(fastTask),
      throwsA(isA<OpenCodeSessionBusyException>()),
    );
    await connector.cancelTask(slowTask.id);
    expect(await firstResult, 'cancelled result');
    expect(abortPaths, ['/session/ses_concurrent/abort']);
    await connector.close();
  });
}
