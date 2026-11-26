import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brigade_bridge/core/bridge_models.dart';
import 'package:brigade_bridge/daemon/artifact_store.dart';
import 'package:brigade_bridge/daemon/database.dart';
import 'package:brigade_bridge/daemon/event_bus.dart';
import 'package:brigade_bridge/daemon/node_registry.dart';
import 'package:brigade_bridge/daemon/permission_manager.dart';
import 'package:brigade_bridge/daemon/project_store.dart';
import 'package:brigade_bridge/daemon/task_scheduler.dart';
import 'package:brigade_bridge/daemon/workflow_engine.dart';
import 'package:brigade_bridge/daemon/ws_server.dart';

void main() {
  test('only an explicit connect registers the selected OpenCode session',
      () async {
    final rig = await _Rig.create();
    addTearDown(rig.dispose);
    final api = await _FakeOpenCodeApi.start('ses_chosen');
    addTearDown(api.close);

    expect(await rig.registry.connectedNodes(), isEmpty);
    final node = await rig.server.connectOpenCode(
      serverUrl: api.url,
      sessionId: 'ses_chosen',
    );
    expect((await rig.registry.connectedNodes()).map((node) => node.id),
        ['opencode:ses_chosen']);
    expect(api.paths, [
      'GET /global/health',
      'GET /session/ses_chosen',
    ]);

    await rig.server.disconnectOpenCode(node.id);
    expect(await rig.registry.connectedNodes(), isEmpty);
    await rig.server.disconnectOpenCode(node.id);
    expect(api.paths.where((path) => path.contains('/session/')), hasLength(1));
  });

  test('routes the task to the explicitly paired session and returns its text',
      () async {
    final rig = await _Rig.create();
    addTearDown(rig.dispose);
    final api = await _FakeOpenCodeApi.start('ses_selected')
      ..messageText = 'OpenCode completed it';
    addTearDown(api.close);
    await rig.server.connectOpenCode(
      serverUrl: api.url,
      sessionId: 'ses_selected',
    );
    final statuses = <TaskStatusChanged>[];
    final subscription = rig.bus.stream.listen((event) {
      if (event is ApprovalRequired) rig.permissions.approve(event.approvalId);
      if (event is TaskStatusChanged) statuses.add(event);
    });
    addTearDown(subscription.cancel);

    await rig.server.runWorkflow({
      'taskText': 'Review this change',
      'projectId': ProjectStore.defaultProjectId,
      'targetNodeId': 'opencode:ses_selected',
    });
    await Future<void>.delayed(Duration.zero);

    expect(api.paths.where((path) => path.endsWith('/message')),
        ['POST /session/ses_selected/message']);
    expect(api.paths.where((path) => path == 'GET /session'), isEmpty);
    expect(api.messageBody!['parts'], isA<List>());
    final completed = statuses.where((event) =>
        event.status == TaskStatus.completed && event.result != null);
    expect(completed.single.result, 'OpenCode completed it');
  });

  test('OpenCode can delegate through Bridge to a manually paired browser tab',
      () async {
    final rig = await _Rig.create(port: 17439);
    addTearDown(rig.dispose);
    final api = await _FakeOpenCodeApi.start('ses_lead')
      ..respondToMessage = (prompt) => prompt
              .contains('Continue your original task')
          ? 'OpenCode final answer'
          : '<<BRIGADE_DELEGATE>>{"targetNodeId":"tab-77","instruction":"Inspect the selected page"}';
    addTearDown(api.close);
    await rig.server.connectOpenCode(
      serverUrl: api.url,
      sessionId: 'ses_lead',
    );
    await rig.server.start();
    final browser = await WebSocket.connect('ws://127.0.0.1:17439');
    addTearDown(browser.close);
    String? delegatedInstruction;
    final browserSubscription = browser.listen((raw) {
      final message = jsonDecode(raw as String) as Map<String, dynamic>;
      if (message['type'] != 'SEND_TASK') return;
      final payload = message['payload'] as Map<String, dynamic>;
      delegatedInstruction = payload['text'] as String;
      browser.add(jsonEncode({
        'type': 'TASK_RESULT',
        'payload': {
          'taskId': payload['taskId'],
          'output': 'Browser helper result',
        },
      }));
    });
    addTearDown(browserSubscription.cancel);
    browser.add(jsonEncode({
      'type': 'REGISTER_TAB',
      'payload': {
        'tabId': 77,
        'title': 'Chosen tab',
        'url': 'https://example.com',
        'capabilities': ['receive_task'],
        'taskDomains': ['general'],
      },
    }));
    await _waitForNode(rig.registry, 'tab-77');
    final subscription = rig.bus.stream.listen((event) {
      if (event is ApprovalRequired) rig.permissions.approve(event.approvalId);
    });
    addTearDown(subscription.cancel);

    await rig.server.runWorkflow({
      'taskText': 'Review and delegate if useful',
      'projectId': ProjectStore.defaultProjectId,
      'targetNodeId': 'opencode:ses_lead',
    });

    expect(delegatedInstruction, contains('Inspect the selected page'));
    expect(api.paths.where((path) => path.endsWith('/message')).length, 2);
    expect(await rig.registry.connectedNodes(), hasLength(2));
  });

  test('rejects a stale session ID without registering another session',
      () async {
    final rig = await _Rig.create();
    addTearDown(rig.dispose);
    final api = await _FakeOpenCodeApi.start('ses_requested')
      ..reportedSessionId = 'ses_other';
    addTearDown(api.close);

    await expectLater(
      rig.server.connectOpenCode(
        serverUrl: api.url,
        sessionId: 'ses_requested',
      ),
      throwsA(isA<HttpException>()),
    );
    expect(api.paths, [
      'GET /global/health',
      'GET /session/ses_requested',
    ]);
    expect(await rig.registry.connectedNodes(), isEmpty);
  });

  test('server failure fails the task and marks the paired session unavailable',
      () async {
    final rig = await _Rig.create();
    addTearDown(rig.dispose);
    final api = await _FakeOpenCodeApi.start('ses_fails')
      ..failMessages = true;
    addTearDown(api.close);
    await rig.server.connectOpenCode(
      serverUrl: api.url,
      sessionId: 'ses_fails',
    );
    final statuses = <TaskStatusChanged>[];
    final subscription = rig.bus.stream.listen((event) {
      if (event is ApprovalRequired) rig.permissions.approve(event.approvalId);
      if (event is TaskStatusChanged) statuses.add(event);
    });
    addTearDown(subscription.cancel);

    await rig.server.runWorkflow({
      'taskText': 'This fails',
      'projectId': ProjectStore.defaultProjectId,
      'targetNodeId': 'opencode:ses_fails',
    });
    await Future<void>.delayed(Duration.zero);

    expect(statuses.any((event) => event.status == TaskStatus.failed), isTrue);
    expect(await rig.registry.connectedNodes(), isEmpty);
  });

  test('rejects a non-assistant message as a task result', () async {
    final rig = await _Rig.create();
    addTearDown(rig.dispose);
    final api = await _FakeOpenCodeApi.start('ses_wrong_role')
      ..messageRole = 'user';
    addTearDown(api.close);
    await rig.server.connectOpenCode(
      serverUrl: api.url,
      sessionId: 'ses_wrong_role',
    );
    final statuses = <TaskStatusChanged>[];
    final subscription = rig.bus.stream.listen((event) {
      if (event is ApprovalRequired) rig.permissions.approve(event.approvalId);
      if (event is TaskStatusChanged) statuses.add(event);
    });
    addTearDown(subscription.cancel);

    await rig.server.runWorkflow({
      'taskText': 'Do not accept this user message',
      'projectId': ProjectStore.defaultProjectId,
      'targetNodeId': 'opencode:ses_wrong_role',
    });
    await Future<void>.delayed(Duration.zero);

    expect(statuses.any((event) => event.status == TaskStatus.failed), isTrue);
  });

  test('workflow cancellation aborts only the paired OpenCode session',
      () async {
    final rig = await _Rig.create();
    addTearDown(rig.dispose);
    final api = await _FakeOpenCodeApi.start('ses_cancel')
      ..holdMessages = true;
    addTearDown(api.close);
    await rig.server.connectOpenCode(
      serverUrl: api.url,
      sessionId: 'ses_cancel',
    );
    final subscription = rig.bus.stream.listen((event) {
      if (event is ApprovalRequired) rig.permissions.approve(event.approvalId);
    });
    addTearDown(subscription.cancel);

    final workflow = rig.server.runWorkflow({
      'taskText': 'Wait and cancel',
      'projectId': ProjectStore.defaultProjectId,
      'targetNodeId': 'opencode:ses_cancel',
    });
    await api.messageStarted.future.timeout(const Duration(seconds: 2));
    rig.server.cancelWorkflow();
    await workflow.timeout(const Duration(seconds: 2));

    expect(api.abortPaths, ['/session/ses_cancel/abort']);
  });

  test('disconnect aborts active work and removes the selected session',
      () async {
    final rig = await _Rig.create();
    addTearDown(rig.dispose);
    final api = await _FakeOpenCodeApi.start('ses_disconnect')
      ..holdMessages = true;
    addTearDown(api.close);
    final node = await rig.server.connectOpenCode(
      serverUrl: api.url,
      sessionId: 'ses_disconnect',
    );
    final statuses = <TaskStatusChanged>[];
    final subscription = rig.bus.stream.listen((event) {
      if (event is ApprovalRequired) rig.permissions.approve(event.approvalId);
      if (event is TaskStatusChanged) statuses.add(event);
    });
    addTearDown(subscription.cancel);

    final workflow = rig.server.runWorkflow({
      'taskText': 'Disconnect during work',
      'projectId': ProjectStore.defaultProjectId,
      'targetNodeId': node.id,
    });
    await api.messageStarted.future.timeout(const Duration(seconds: 2));
    await rig.server.disconnectOpenCode(node.id);
    await workflow.timeout(const Duration(seconds: 2));
    await Future<void>.delayed(Duration.zero);

    expect(api.abortPaths, ['/session/ses_disconnect/abort']);
    expect(statuses.any((event) => event.status == TaskStatus.failed), isTrue);
    expect(await rig.registry.connectedNodes(), isEmpty);
  });
}

class _Rig {
  _Rig(this.db, this.bus, this.registry, this.permissions, this.server,
      this.tempDir);

  final BridgeDatabase db;
  final EventBus bus;
  final NodeRegistry registry;
  final PermissionManager permissions;
  final WsServer server;
  final Directory tempDir;

  static Future<_Rig> create({int port = 0}) async {
    final db = BridgeDatabase(NativeDatabase.memory());
    final bus = EventBus();
    final registry = NodeRegistry(db, bus);
    final permissions = PermissionManager(db, bus);
    final scheduler = TaskScheduler(db, bus, retryDelay: Duration.zero);
    final tempDir = await Directory.systemTemp.createTemp('opencode-bridge-');
    final engine = WorkflowEngine(
      registry: registry,
      scheduler: scheduler,
      permissionManager: permissions,
      artifactStore: ArtifactStore(tempDir),
      bus: bus,
    );
    final server = WsServer(
      port: port,
      bus: bus,
      engine: engine,
      registry: registry,
      pm: permissions,
    );
    return _Rig(db, bus, registry, permissions, server, tempDir);
  }

  Future<void> dispose() async {
    await server.stop();
    bus.dispose();
    await db.close();
    await tempDir.delete(recursive: true);
  }
}

class _FakeOpenCodeApi {
  _FakeOpenCodeApi(this.server, this.sessionId);

  final HttpServer server;
  final String sessionId;
  final paths = <String>[];
  String messageText = 'done';
  bool failMessages = false;
  bool holdMessages = false;
  String? reportedSessionId;
  String messageRole = 'assistant';
  String Function(String prompt)? respondToMessage;
  final messageStarted = Completer<void>();
  final abortReceived = Completer<void>();
  final abortPaths = <String>[];
  Map<String, dynamic>? messageBody;

  String get url => 'http://127.0.0.1:${server.port}';

  static Future<_FakeOpenCodeApi> start(String sessionId) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final api = _FakeOpenCodeApi(server, sessionId);
    server.listen(api._handle);
    return api;
  }

  Future<void> _handle(HttpRequest request) async {
    paths.add('${request.method} ${request.uri.path}');
    if (request.method == 'GET' && request.uri.path == '/global/health') {
      request.response.write(jsonEncode({'healthy': true, 'version': 'test'}));
    } else if (request.method == 'GET' &&
        request.uri.path == '/session/$sessionId') {
      request.response
          .write(jsonEncode({'id': reportedSessionId ?? sessionId}));
    } else if (request.method == 'POST' &&
        request.uri.path == '/session/$sessionId/message') {
      messageBody = Map<String, dynamic>.from(
          jsonDecode(await utf8.decoder.bind(request).join()) as Map);
      final parts = messageBody!['parts'] as List? ?? const [];
      final prompt = parts
          .whereType<Map>()
          .map((part) => part['text'])
          .whereType<String>()
          .join('\n');
      if (holdMessages) {
        if (!messageStarted.isCompleted) messageStarted.complete();
        await abortReceived.future;
      }
      if (failMessages) {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write('failed');
      } else {
        request.response.write(jsonEncode({
          'info': {'role': messageRole},
          'parts': [
            {
              'type': 'text',
              'text': respondToMessage?.call(prompt) ?? messageText,
            },
          ],
        }));
      }
    } else if (request.method == 'POST' &&
        request.uri.path == '/session/$sessionId/abort') {
      abortPaths.add(request.uri.path);
      if (!abortReceived.isCompleted) abortReceived.complete();
      request.response.write('true');
    } else {
      request.response.statusCode = HttpStatus.notFound;
    }
    await request.response.close();
  }

  Future<void> close() => server.close(force: true);
}

Future<void> _waitForNode(NodeRegistry registry, String id) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if ((await registry.connectedNodes()).any((node) => node.id == id)) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Node $id was not registered');
}
