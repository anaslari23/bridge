import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_codex_server.dart';

void main() {
  test('only an explicit connect registers the selected Codex thread',
      () async {
    final rig = await _Rig.create();
    addTearDown(rig.dispose);
    final codex = await FakeCodexServer.start();
    addTearDown(codex.close);

    expect(await rig.registry.connectedNodes(), isEmpty);
    final node = await rig.server.connectCodex(
      serverUrl: codex.url,
      threadId: 'thr_1',
    );
    expect((await rig.registry.connectedNodes()).map((n) => n.id),
        ['codex:thr_1']);
    expect(node.adapterId, 'codex-app-server');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(codex.received.map((m) => m['method']),
        isNot(contains('thread/list')));

    await rig.server.disconnectCodex(node.id);
    expect(await rig.registry.connectedNodes(), isEmpty);
    await rig.server.disconnectCodex(node.id); // idempotent
  });

  test('routes a workflow task to the paired thread and returns its answer',
      () async {
    final rig = await _Rig.create();
    addTearDown(rig.dispose);
    final codex = await FakeCodexServer.start()
      ..onTurnStart = (s, _) {
        s.agentMessage('Codex completed it', phase: 'final_answer');
        s.turnCompleted('completed');
      };
    addTearDown(codex.close);
    await rig.server.connectCodex(serverUrl: codex.url, threadId: 'thr_1');
    final statuses = <TaskStatusChanged>[];
    final subscription = rig.bus.stream.listen((event) {
      if (event is ApprovalRequired) rig.permissions.approve(event.approvalId);
      if (event is TaskStatusChanged) statuses.add(event);
    });
    addTearDown(subscription.cancel);

    await rig.server.runWorkflow({
      'taskText': 'Review this change',
      'projectId': ProjectStore.defaultProjectId,
      'targetNodeId': 'codex:thr_1',
    });
    await Future<void>.delayed(Duration.zero);

    final completed = statuses.where((event) =>
        event.status == TaskStatus.completed && event.result != null);
    expect(completed.single.result, 'Codex completed it');
    expect(codex.lastTurnText, contains('Review this change'));
    expect(codex.lastTurnText, contains('<<BRIGADE_DELEGATE>>'));
  });

  test('Codex can delegate through Bridge to a manually paired browser tab',
      () async {
    final rig = await _Rig.create(port: 17441);
    addTearDown(rig.dispose);
    final codex = await FakeCodexServer.start();
    codex.onTurnStart = (s, _) {
      final continuing =
          (s.lastTurnText ?? '').contains('Continue your original task');
      s.agentMessage(
        continuing
            ? 'Codex final answer'
            : '<<BRIGADE_DELEGATE>>{"targetNodeId":"tab-77","instruction":"Inspect the selected page"}',
        phase: 'final_answer',
      );
      s.turnCompleted('completed');
    };
    addTearDown(codex.close);
    await rig.server.connectCodex(serverUrl: codex.url, threadId: 'thr_1');
    await rig.server.start();

    final browser = await WebSocket.connect('ws://127.0.0.1:17441');
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
    final results = <String>[];
    final subscription = rig.bus.stream.listen((event) {
      if (event is ApprovalRequired) rig.permissions.approve(event.approvalId);
      if (event is TaskStatusChanged &&
          event.status == TaskStatus.completed &&
          event.result != null) {
        results.add(event.result!);
      }
    });
    addTearDown(subscription.cancel);

    await rig.server.runWorkflow({
      'taskText': 'Review and delegate if useful',
      'projectId': ProjectStore.defaultProjectId,
      'targetNodeId': 'codex:thr_1',
    });
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(delegatedInstruction, contains('Inspect the selected page'));
    expect(codex.lastTurnText, contains('Browser helper result'));
    expect(results, contains('Codex final answer'));
  });

  test('marks the node unavailable when the app-server connection drops',
      () async {
    final rig = await _Rig.create();
    addTearDown(rig.dispose);
    final codex = await FakeCodexServer.start();
    addTearDown(codex.close);
    await rig.server.connectCodex(serverUrl: codex.url, threadId: 'thr_1');
    expect(await rig.registry.connectedNodes(), hasLength(1));

    await codex.socket!.close();
    await _waitUntil(() async => (await rig.registry.connectedNodes()).isEmpty);
    expect(await rig.registry.connectedNodes(), isEmpty);
  });
}

Future<void> _waitForNode(NodeRegistry registry, String id) =>
    _waitUntil(() async =>
        (await registry.connectedNodes()).any((node) => node.id == id));

Future<void> _waitUntil(Future<bool> Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition was not met in time');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
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
    final tempDir = await Directory.systemTemp.createTemp('codex-bridge-');
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
