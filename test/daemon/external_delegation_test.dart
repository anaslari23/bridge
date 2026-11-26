import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:brigade_bridge/daemon/artifact_store.dart';
import 'package:brigade_bridge/daemon/database.dart';
import 'package:brigade_bridge/daemon/event_bus.dart';
import 'package:brigade_bridge/daemon/node_registry.dart';
import 'package:brigade_bridge/daemon/permission_manager.dart';
import 'package:brigade_bridge/daemon/task_scheduler.dart';
import 'package:brigade_bridge/daemon/workflow_engine.dart';
import 'package:brigade_bridge/daemon/ws_server.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Claude Desktop extension talks to the daemon as an authenticated
/// loopback client. These tests pin the protocol it relies on.
void main() {
  late BridgeDatabase db;
  late EventBus bus;
  late NodeRegistry registry;
  late PermissionManager permissions;
  late WorkflowEngine engine;
  late WsServer server;
  late Directory tempDir;
  const port = 17444;

  setUp(() async {
    db = BridgeDatabase(NativeDatabase.memory());
    bus = EventBus();
    registry = NodeRegistry(db, bus);
    permissions = PermissionManager(db, bus);
    tempDir = await Directory.systemTemp.createTemp('external-delegation-');
    engine = WorkflowEngine(
      registry: registry,
      scheduler: TaskScheduler(db, bus, retryDelay: Duration.zero),
      permissionManager: permissions,
      artifactStore: ArtifactStore(tempDir),
      bus: bus,
    );
    server = WsServer(
      port: port,
      bus: bus,
      engine: engine,
      registry: registry,
      pm: permissions,
      authToken: 'tok',
    );
    await server.start();
    bus.stream.listen((event) {
      if (event is ApprovalRequired) permissions.approve(event.approvalId);
    });
  });

  tearDown(() async {
    await server.stop();
    bus.dispose();
    await db.close();
    await tempDir.delete(recursive: true);
  });

  Future<(WebSocket, Stream<Map<String, dynamic>>)> client() async {
    final ws = await WebSocket.connect('ws://127.0.0.1:$port');
    final messages = ws
        .map((raw) => Map<String, dynamic>.from(jsonDecode(raw as String) as Map))
        .asBroadcastStream();
    ws.add(jsonEncode({
      'type': 'AUTHENTICATE',
      'payload': {'token': 'tok'},
    }));
    await messages.firstWhere((m) => m['type'] == 'AUTHENTICATED');
    addTearDown(ws.close);
    return (ws, messages);
  }

  Future<WebSocket> registerTab(int id) async {
    final tab = await WebSocket.connect('ws://127.0.0.1:$port');
    addTearDown(tab.close);
    tab.add(jsonEncode({
      'type': 'AUTHENTICATE',
      'payload': {'token': 'tok'},
    }));
    tab.listen((raw) {
      final message = jsonDecode(raw as String) as Map<String, dynamic>;
      if (message['type'] != 'SEND_TASK') return;
      final payload = message['payload'] as Map<String, dynamic>;
      tab.add(jsonEncode({
        'type': 'TASK_RESULT',
        'payload': {'taskId': payload['taskId'], 'output': 'tab answer'},
      }));
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));
    tab.add(jsonEncode({
      'type': 'REGISTER_TAB',
      'payload': {
        'tabId': id,
        'title': 'Helper tab',
        'url': 'https://example.com',
        'capabilities': ['receive_task'],
        'taskDomains': ['general'],
      },
    }));
    for (var i = 0; i < 100; i++) {
      if ((await registry.connectedNodes()).any((n) => n.id == 'tab-$id')) {
        return tab;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    throw StateError('tab did not register');
  }

  test('LIST_NODES reports kind, capabilities and task domains', () async {
    await registerTab(5);
    final (ws, messages) = await client();
    ws.add(jsonEncode({'type': 'LIST_NODES', 'payload': {}}));
    final list = await messages.firstWhere((m) => m['type'] == 'NODE_LIST');
    final nodes = (list['payload'] as Map)['nodes'] as List;
    final node = nodes.cast<Map>().firstWhere((n) => n['id'] == 'tab-5');
    expect(node['name'], isNotEmpty);
    expect(node['kind'], 'browser');
    expect(node['capabilities'], contains('receive_task'));
    expect(node['taskDomains'], contains('general'));
  });

  test('an external dispatch runs and its status events carry the workflow id',
      () async {
    await registerTab(6);
    final (ws, messages) = await client();
    final events = <Map<String, dynamic>>[];
    final sub = messages.listen(events.add);
    addTearDown(sub.cancel);

    ws.add(jsonEncode({
      'type': 'RUN_WORKFLOW',
      'payload': {
        'taskText': 'Summarise the page',
        'targetNodeId': 'tab-6',
        'workflowId': 'mcp-job-1',
        'origin': 'external',
      },
    }));
    final done = await messages.firstWhere((m) =>
        m['type'] == 'TASK_STATUS_CHANGED' &&
        (m['payload'] as Map)['status'] == 'completed' &&
        (m['payload'] as Map)['workflowId'] == 'mcp-job-1');
    final payload = done['payload'] as Map;
    expect(payload['result'], 'tab answer');
    expect(payload['sourceNodeId'], 'user');
    expect(payload['targetNodeId'], 'tab-6');
  });

  test('an external dispatch cannot clear the user\'s emergency stop',
      () async {
    await registerTab(7);
    final (ws, messages) = await client();
    ws.add(jsonEncode({'type': 'STOP_ALL', 'payload': {}}));
    await messages.firstWhere((m) => m['type'] == 'STOP_ALL');
    expect(engine.isStopped, isTrue);

    final errors = <String>[];
    final sub = messages.listen((m) {
      if (m['type'] == 'PROTOCOL_ERROR') {
        errors.add((m['payload'] as Map)['reason'] as String);
      }
    });
    addTearDown(sub.cancel);
    ws.add(jsonEncode({
      'type': 'RUN_WORKFLOW',
      'payload': {
        'taskText': 'x',
        'targetNodeId': 'tab-7',
        'workflowId': 'mcp-job-2',
        'origin': 'external',
      },
    }));
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(engine.isStopped, isTrue);
    expect(errors.single, contains('Bridge is stopped'));
  });

  test('a normal dispatch still resumes after an emergency stop', () async {
    await registerTab(8);
    final (ws, messages) = await client();
    ws.add(jsonEncode({'type': 'STOP_ALL', 'payload': {}}));
    await messages.firstWhere((m) => m['type'] == 'STOP_ALL');
    expect(engine.isStopped, isTrue);

    ws.add(jsonEncode({
      'type': 'RUN_WORKFLOW',
      'payload': {'taskText': 'resume please', 'targetNodeId': 'tab-8'},
    }));
    await messages.firstWhere((m) =>
        m['type'] == 'TASK_STATUS_CHANGED' &&
        (m['payload'] as Map)['status'] == 'completed');
    expect(engine.isStopped, isFalse);
  });

  test('an unauthenticated client cannot list nodes or run workflows',
      () async {
    final ws = await WebSocket.connect('ws://127.0.0.1:$port');
    addTearDown(ws.close);
    final messages = ws
        .map((raw) => Map<String, dynamic>.from(jsonDecode(raw as String) as Map))
        .asBroadcastStream();
    final errors = messages.where((m) => m['type'] == 'PROTOCOL_ERROR').take(2).toList();
    ws.add(jsonEncode({'type': 'LIST_NODES', 'payload': {}}));
    ws.add(jsonEncode({
      'type': 'RUN_WORKFLOW',
      'payload': {'taskText': 'x', 'origin': 'external'},
    }));
    expect((await errors).length, 2);
    expect(engine.isStopped, isFalse);
  });
}
