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

/// The real daemon and the real extension process, speaking MCP over stdio.
/// Skipped when Node or the extension's dependencies are not installed.
void main() {
  final extensionDir = '${Directory.current.path}/claude-desktop-extension';
  final entry = '$extensionDir/server/index.js';
  final ready = Directory('$extensionDir/node_modules/@modelcontextprotocol').existsSync() &&
      (Process.runSync('node', ['--version']).exitCode == 0);
  const port = 17445;

  late BridgeDatabase db;
  late EventBus bus;
  late NodeRegistry registry;
  late PermissionManager permissions;
  late WorkflowEngine engine;
  late WsServer server;
  late Directory tempDir;
  Process? extension;
  final pending = <int, Completer<Map<String, dynamic>>>{};
  var nextId = 1;
  var autoApprove = true;
  final approvals = <String>[];

  setUp(() async {
    if (!ready) return;
    db = BridgeDatabase(NativeDatabase.memory());
    bus = EventBus();
    registry = NodeRegistry(db, bus);
    permissions = PermissionManager(db, bus);
    tempDir = await Directory.systemTemp.createTemp('desktop-ext-');
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
        authToken: 'real-token');
    await server.start();
    autoApprove = true;
    approvals.clear();
    bus.stream.listen((event) {
      if (event is ApprovalRequired) {
        approvals.add(event.approvalId);
        if (autoApprove) permissions.approve(event.approvalId);
      }
    });

    // A connected browser tab that answers every task.
    final tab = await WebSocket.connect('ws://127.0.0.1:$port');
    addTearDown(tab.close);
    tab.add(jsonEncode({
      'type': 'AUTHENTICATE',
      'payload': {'token': 'real-token'},
    }));
    tab.listen((raw) {
      final message = jsonDecode(raw as String) as Map<String, dynamic>;
      if (message['type'] != 'SEND_TASK') return;
      final payload = message['payload'] as Map<String, dynamic>;
      tab.add(jsonEncode({
        'type': 'TASK_RESULT',
        'payload': {
          'taskId': payload['taskId'],
          'output': 'tab answer to: ${payload['text']}'.split('\n').first,
        },
      }));
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));
    tab.add(jsonEncode({
      'type': 'REGISTER_TAB',
      'payload': {
        'tabId': 9,
        'title': 'Helper tab',
        'url': 'https://example.com',
        'capabilities': ['receive_task'],
        'taskDomains': ['general'],
      },
    }));
    for (var i = 0; i < 100; i++) {
      if ((await registry.connectedNodes()).any((n) => n.id == 'tab-9')) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  });

  tearDown(() async {
    if (!ready) return;
    extension?.kill();
    extension = null;
    pending.clear();
    await server.stop();
    bus.dispose();
    await db.close();
    await tempDir.delete(recursive: true);
  });

  Future<Map<String, dynamic>> rpc(String method, Map<String, dynamic> params) {
    final id = nextId++;
    final completer = Completer<Map<String, dynamic>>();
    pending[id] = completer;
    extension!.stdin.writeln(jsonEncode(
        {'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params}));
    return completer.future.timeout(const Duration(seconds: 20));
  }

  Future<void> startExtension({String token = 'real-token'}) async {
    extension = await Process.start('node', [entry], environment: {
      'PATH': Platform.environment['PATH'] ?? '',
      'BRIDGE_URL': 'ws://127.0.0.1:$port',
      'BRIDGE_TOKEN': token,
    });
    extension!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      final decoded = jsonDecode(line);
      if (decoded is Map && decoded['id'] is int) {
        pending.remove(decoded['id'])?.complete(Map<String, dynamic>.from(decoded));
      }
    });
    extension!.stderr.drain<void>();
    await rpc('initialize', {
      'protocolVersion': '2025-06-18',
      'capabilities': <String, dynamic>{},
      'clientInfo': {'name': 'dart-test', 'version': '1'},
    });
    extension!.stdin.writeln(
        jsonEncode({'jsonrpc': '2.0', 'method': 'notifications/initialized'}));
  }

  Future<Map<String, dynamic>> call(String tool, Map<String, dynamic> args) async {
    final response = await rpc('tools/call', {'name': tool, 'arguments': args});
    final result = Map<String, dynamic>.from(response['result'] as Map);
    final text = (result['content'] as List).map((c) => (c as Map)['text']).join('\n');
    Object? body;
    try {
      body = jsonDecode(text);
    } on FormatException {
      body = text;
    }
    return {'isError': result['isError'] == true, 'body': body, 'text': text};
  }

  test('lists the real daemon\'s connected tab', () async {
    await startExtension();
    final out = await call('bridge_list_nodes', {});
    expect(out['isError'], isFalse);
    final nodes = (out['body'] as List).cast<Map>();
    expect(nodes.map((n) => n['id']), contains('tab-9'));
    expect(nodes.firstWhere((n) => n['id'] == 'tab-9')['kind'], 'browser');
  }, skip: ready ? false : 'Node or extension dependencies not installed');

  test('delegates a task through the real daemon and returns the answer',
      () async {
    await startExtension();
    final out = await call('bridge_delegate',
        {'node_id': 'tab-9', 'instruction': 'Say hello', 'wait_seconds': 10});
    expect(out['isError'], isFalse, reason: out['text'] as String);
    final body = out['body'] as Map;
    expect(body['status'], 'completed');
    expect(body['result'], contains('tab answer'));
  }, skip: ready ? false : 'Node or extension dependencies not installed');

  test('Bridge\'s approval gate holds the task until the user approves',
      () async {
    autoApprove = false;
    await startExtension();
    final first = await call('bridge_delegate',
        {'node_id': 'tab-9', 'instruction': 'Needs approval', 'wait_seconds': 2});
    expect(approvals, isNotEmpty, reason: 'Bridge never asked for approval');
    expect((first['body'] as Map)['status'], 'waiting_for_approval');
    expect((first['body'] as Map)['note'], contains('approve'));

    permissions.approve(approvals.first);
    final done = await call('bridge_get_result',
        {'job_id': (first['body'] as Map)['job_id'], 'wait_seconds': 10});
    expect((done['body'] as Map)['status'], 'completed');
  }, skip: ready ? false : 'Node or extension dependencies not installed');

  test('delegation is refused while the user\'s emergency stop is active',
      () async {
    await startExtension();
    engine.emergencyStop();
    final out = await call('bridge_delegate',
        {'node_id': 'tab-9', 'instruction': 'Sneak past stop', 'wait_seconds': 10});
    expect(out['isError'], isTrue);
    expect(out['text'], contains('Bridge is stopped'));
    expect(engine.isStopped, isTrue);
  }, skip: ready ? false : 'Node or extension dependencies not installed');

  test('a wrong pairing token is reported clearly', () async {
    await startExtension(token: 'wrong-token');
    final out = await call('bridge_list_nodes', {});
    expect(out['isError'], isTrue);
    expect(out['text'], contains('token'));
  }, skip: ready ? false : 'Node or extension dependencies not installed');
}
