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

import 'support/fake_agy.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('agy-int-');
  });
  tearDown(() => dir.delete(recursive: true));

  test('connect fails cleanly and registers nothing when agy is missing',
      () async {
    final rig = await _Rig.create(agyPath: '${dir.path}/nope');
    addTearDown(rig.dispose);
    await expectLater(
      rig.server.connectAntigravity(workingDirectory: dir.path),
      throwsStateError,
    );
    expect(await rig.registry.connectedNodes(), isEmpty);
  });

  test('only an explicit connect registers Antigravity; disconnect removes it',
      () async {
    final rig = await _Rig.create(agyPath: await writeFakeAgy(dir));
    addTearDown(rig.dispose);
    expect(await rig.registry.connectedNodes(), isEmpty);

    final node =
        await rig.server.connectAntigravity(workingDirectory: dir.path);
    expect((await rig.registry.connectedNodes()).map((n) => n.id),
        ['antigravity:new']);
    await expectLater(
      rig.server.connectAntigravity(workingDirectory: dir.path),
      throwsStateError, // one session at a time
    );

    await rig.server.disconnectAntigravity(node.id);
    expect(await rig.registry.connectedNodes(), isEmpty);
    await rig.server.disconnectAntigravity(node.id); // idempotent
  });

  test('routes a workflow task to Antigravity and returns its answer',
      () async {
    final rig = await _Rig.create(agyPath: await writeFakeAgy(dir));
    addTearDown(rig.dispose);
    await rig.server.connectAntigravity(workingDirectory: dir.path);
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
      'taskText': 'Review this change',
      'projectId': ProjectStore.defaultProjectId,
      'targetNodeId': 'antigravity:new',
    });
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(results, ['Antigravity answer']);
  });

  test('Antigravity can delegate through Bridge to a manually paired tab',
      () async {
    final rig = await _Rig.create(
        agyPath: await writeFakeAgy(dir), port: 17442);
    addTearDown(rig.dispose);
    await rig.server.connectAntigravity(workingDirectory: dir.path);
    await rig.server.start();

    final browser = await WebSocket.connect('ws://127.0.0.1:17442');
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
    await _waitUntil(() async => (await rig.registry.connectedNodes())
        .any((node) => node.id == 'tab-77'));
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
      'taskText': 'DELEGATE_ME to the browser',
      'projectId': ProjectStore.defaultProjectId,
      'targetNodeId': 'antigravity:new',
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(delegatedInstruction, contains('Inspect the selected page'));
    expect(results, contains('Antigravity final answer'));
    // The continuation turn resumed the conversation learned from the first.
    final args = File('${dir.path}/args.log').readAsLinesSync();
    expect(args, hasLength(2));
    expect(args.last, contains('--conversation c-new-123'));
  });
}

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

  static Future<_Rig> create({required String agyPath, int port = 0}) async {
    final db = BridgeDatabase(NativeDatabase.memory());
    final bus = EventBus();
    final registry = NodeRegistry(db, bus);
    final permissions = PermissionManager(db, bus);
    final scheduler = TaskScheduler(db, bus, retryDelay: Duration.zero);
    final tempDir = await Directory.systemTemp.createTemp('agy-bridge-');
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
      antigravityExecutable: agyPath,
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
