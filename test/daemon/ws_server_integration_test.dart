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
import 'package:brigade_bridge/daemon/task_scheduler.dart';
import 'package:brigade_bridge/daemon/workflow_engine.dart';
import 'package:brigade_bridge/daemon/ws_server.dart';

void main() {
  test('routes a task to the registered tab and accepts its result', () async {
    final db = BridgeDatabase(NativeDatabase.memory());
    final bus = EventBus();
    final attachmentDir =
        await Directory.systemTemp.createTemp('bridge-attachment-test-');
    final attachmentFile = File('${attachmentDir.path}/brief.txt');
    await attachmentFile.writeAsString('brief');
    addTearDown(() async {
      bus.dispose();
      await db.close();
      await attachmentDir.delete(recursive: true);
    });
    final registry = NodeRegistry(db, bus);
    final permissions = PermissionManager(db, bus);
    final scheduler = TaskScheduler(db, bus);
    final engine = WorkflowEngine(
      registry: registry,
      scheduler: scheduler,
      permissionManager: permissions,
      artifactStore:
          ArtifactStore(Directory.systemTemp.createTempSync('bridge-test-')),
      bus: bus,
    );
    final server = WsServer(
        port: 17432,
        bus: bus,
        engine: engine,
        registry: registry,
        pm: permissions,
        authToken: 'test-local-token');
    await server.start();
    addTearDown(server.stop);
    final socket = await WebSocket.connect('ws://127.0.0.1:17432');
    final rogueSocket = await WebSocket.connect('ws://127.0.0.1:17432');
    final badSocket = await WebSocket.connect('ws://127.0.0.1:17432');
    final unauthenticatedSocket =
        await WebSocket.connect('ws://127.0.0.1:17432');
    addTearDown(socket.close);
    addTearDown(rogueSocket.close);
    addTearDown(badSocket.close);
    addTearDown(unauthenticatedSocket.close);
    final rogueMessages = <Map<String, dynamic>>[];
    final rogueProtocolError = Completer<void>();
    rogueSocket.listen((raw) {
      final message = jsonDecode(raw as String) as Map<String, dynamic>;
      rogueMessages.add(message);
      if (message['type'] == 'PROTOCOL_ERROR' &&
          !rogueProtocolError.isCompleted) rogueProtocolError.complete();
    });
    final badMessages = <Map<String, dynamic>>[];
    final badProtocolError = Completer<void>();
    badSocket.listen((raw) {
      final message = jsonDecode(raw as String) as Map<String, dynamic>;
      badMessages.add(message);
      if (message['type'] == 'PROTOCOL_ERROR' && !badProtocolError.isCompleted)
        badProtocolError.complete();
    });
    final unauthenticatedMessages = <Map<String, dynamic>>[];
    final unauthenticatedProtocolError = Completer<void>();
    final unauthenticatedSubscription = unauthenticatedSocket.listen((raw) {
      final message = jsonDecode(raw as String) as Map<String, dynamic>;
      unauthenticatedMessages.add(message);
      if (message['type'] == 'PROTOCOL_ERROR' &&
          !unauthenticatedProtocolError.isCompleted) {
        unauthenticatedProtocolError.complete();
      }
    });
    addTearDown(unauthenticatedSubscription.cancel);
    final messages = <Map<String, dynamic>>[];
    String? completedResult;
    final eventSubscription = bus.stream.listen((event) {
      if (event is TaskStatusChanged && event.status == TaskStatus.completed) {
        completedResult = event.result;
      }
    });
    addTearDown(eventSubscription.cancel);
    final done = Completer<void>();
    Completer<void>? currentCompletion = done;
    final registeredEvents = <NodeRegistered>[];
    final nodeSubscription = bus.stream.listen((event) {
      if (event is NodeRegistered) registeredEvents.add(event);
    });
    addTearDown(nodeSubscription.cancel);
    socket.add(jsonEncode({
      'type': 'AUTHENTICATE',
      'payload': {'token': 'test-local-token'}
    }));
    rogueSocket.add(jsonEncode({
      'type': 'AUTHENTICATE',
      'payload': {'token': 'test-local-token'}
    }));
    badSocket.add(jsonEncode({
      'type': 'AUTHENTICATE',
      'payload': {'token': 'wrong-token'}
    }));
    unauthenticatedSocket.add(jsonEncode({
      'type': 'REGISTER_TAB',
      'payload': {
        'tabId': 99,
        'title': 'Unpaired',
        'url': 'https://example.com',
      }
    }));
    await badProtocolError.future.timeout(const Duration(seconds: 2));
    expect(badMessages.any((message) => message['type'] == 'PROTOCOL_ERROR'),
        isTrue);
    await unauthenticatedProtocolError.future
        .timeout(const Duration(seconds: 2));
    expect(
        unauthenticatedMessages
            .any((message) => message['type'] == 'PROTOCOL_ERROR'),
        isTrue);
    expect(await registry.allNodes(), isEmpty);
    rogueSocket.add('{not-json');
    await rogueProtocolError.future.timeout(const Duration(seconds: 2));
    expect(rogueMessages.any((message) => message['type'] == 'PROTOCOL_ERROR'),
        isTrue);
    socket.listen((raw) {
      final message = jsonDecode(raw as String) as Map<String, dynamic>;
      messages.add(message);
      final type = message['type'];
      final payload = message['payload'] as Map<String, dynamic>? ?? {};
      if (type == 'APPROVAL_REQUIRED') {
        socket.add(jsonEncode({
          'type': 'APPROVE_TASK',
          'payload': {'taskId': payload['taskId']}
        }));
      } else if (type == 'SEND_TASK') {
        // A different adapter socket must not be able to spoof this result.
        rogueSocket.add(jsonEncode({
          'type': 'TASK_RESULT',
          'payload': {'taskId': payload['taskId'], 'output': 'spoofed result'}
        }));
        final nodeId = payload['nodeId'] as String?;
        final taskText = payload['text'] as String? ?? '';
        final output = nodeId == 'tab-7' &&
                taskText.contains('Continue your original task')
            ? 'lead final result'
            : nodeId == 'tab-7' && taskText.contains('DELEGATE_TEST')
                ? '<<BRIGADE_DELEGATE>>{"targetNodeId":"tab-8","instruction":"check this subtask"}'
                : nodeId == 'tab-8'
                    ? 'helper result'
                    : 'tab result';
        Future<void>.delayed(const Duration(milliseconds: 30), () {
          socket.add(jsonEncode({
            'type': 'TASK_RESULT',
            'payload': {'taskId': payload['taskId'], 'output': output}
          }));
        });
      } else if (type == 'INSPECT_TAB') {
        socket.add(jsonEncode({
          'type': 'TAB_INSPECTION',
          'payload': {
            'requestId': payload['requestId'],
            'output': 'visible tab text'
          }
        }));
      } else if (type == 'WEB_RESEARCH_REQUEST') {
        rogueSocket.add(jsonEncode({
          'type': 'WEB_RESEARCH_RESULT',
          'payload': {
            'requestId': payload['requestId'],
            'query': payload['query'],
            'pageText': 'Spoofed research result',
            'sources': [],
          },
        }));
        socket.add(jsonEncode({
          'type': 'WEB_RESEARCH_RESULT',
          'payload': {
            'requestId': payload['requestId'],
            'query': payload['query'],
            'pageText': 'Visible connected-tab search result',
            'sources': [
              {'title': 'Research source', 'url': 'https://example.com/source'}
            ],
          },
        }));
      } else if (type == 'LOG_ENTRY' &&
          (payload['message'] as String).contains('Workflow completed')) {
        if (currentCompletion != null && !currentCompletion!.isCompleted) {
          currentCompletion!.complete();
        }
      }
    });
    socket.add(jsonEncode({
      'type': 'REGISTER_TAB',
      'payload': {
        'tabId': 7,
        'identity': 'Test Agent',
        'title': 'Test Agent',
        'url': 'https://claude.ai/new',
        'windowId': 42,
        'capabilities': ['read_text', 'send_text', 'receive_task'],
        'taskDomains': ['planning', 'general'],
      }
    }));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await server.inspectTab('tab-7'), 'visible tab text');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(registeredEvents.map((event) => event.node.id), ['tab-7']);
    rogueSocket.add(jsonEncode({
      'type': 'TAB_REMOVED',
      'payload': {'tabId': 7},
    }));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect((await registry.connectedNodes()).single.id, 'tab-7');
    await server.runWorkflow({
      'nodes': [
        {
          'id': 'tab-7',
          'name': 'Test Agent',
          'kind': 'browser',
          'detail': 'https://claude.ai/new',
          'tabId': 7,
          'url': 'https://claude.ai/new'
        }
      ],
      'edges': [],
      'taskText': 'delegate this',
      'contextNodeIds': ['tab-7'],
      'attachments': [
        {
          'name': 'brief.txt',
          'sizeBytes': 5,
          'mimeType': 'text/plain',
          'path': attachmentFile.path,
        }
      ],
    });
    await done.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () => throw StateError(
          'workflow did not complete; messages=${messages.map((message) => message['type']).toList()}'),
    );
    expect(completedResult, 'tab result');
    expect(messages.any((m) => m['type'] == 'SEND_TASK'), isTrue);
    final send = messages.firstWhere((m) => m['type'] == 'SEND_TASK');
    expect(send['payload']['text'], contains('visible tab text'));
    expect(send['payload']['contextNodeIds'], ['tab-7']);
    final attachment =
        (send['payload']['attachments'] as List).single as Map<String, dynamic>;
    expect(attachment['name'], 'brief.txt');
    expect(attachment['sizeBytes'], 5);
    expect(attachment['mimeType'], 'text/plain');
    expect(attachment['dataBase64'], base64Encode(utf8.encode('brief')));
    expect(attachment.containsKey('path'), isFalse);
    expect(
        messages.any((m) =>
            m['type'] == 'LOG_ENTRY' &&
            (m['payload']['message'] as String).contains('Workflow completed')),
        isTrue);

    socket.add(jsonEncode({
      'type': 'HEARTBEAT',
      'payload': {
        'tabId': 7,
        'title': 'Test Agent',
        'url': 'https://claude.ai/thread/changed',
        'windowId': 42,
      },
    }));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect((await registry.allNodes()).single.health, 'degraded');
    final sendsBeforeIdentityPause =
        messages.where((message) => message['type'] == 'SEND_TASK').length;
    await server.runWorkflow({
      'nodes': [
        {
          'id': 'tab-7',
          'name': 'Test Agent',
          'kind': 'browser',
          'detail': 'https://claude.ai/new',
          'tabId': 7,
          'url': 'https://claude.ai/new'
        }
      ],
      'edges': [],
      'taskText': 'must pause after navigation',
    });
    expect(messages.where((message) => message['type'] == 'SEND_TASK').length,
        sendsBeforeIdentityPause);

    socket.add(jsonEncode({
      'type': 'REGISTER_TAB',
      'payload': {
        'tabId': 7,
        'identity': 'Test Agent',
        'title': 'Test Agent',
        'url': 'https://claude.ai/thread/changed',
        'windowId': 42,
      }
    }));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect((await registry.allNodes()).single.health, 'connected');

    socket.add(jsonEncode({
      'type': 'HEARTBEAT',
      'payload': {
        'tabId': 7,
        'title': 'Test Agent',
        'url': 'https://claude.ai/thread/changed',
        'windowId': 43,
      },
    }));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect((await registry.allNodes()).single.health, 'degraded');

    socket.add(jsonEncode({
      'type': 'REGISTER_TAB',
      'payload': {
        'tabId': 7,
        'identity': 'Test Agent',
        'title': 'Test Agent',
        'url': 'https://claude.ai/thread/changed',
        'windowId': 43,
      }
    }));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect((await registry.allNodes()).single.health, 'connected');

    socket.add(jsonEncode({
      'type': 'ADAPTER_HEALTH',
      'payload': {'tabId': 7, 'health': 'requires_update'},
    }));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect((await registry.allNodes()).single.health, 'requires_update');

    socket.add(jsonEncode({
      'type': 'TAB_REMOVED',
      'payload': {'tabId': 7},
    }));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await registry.allNodes(), isEmpty);
    expect(await registry.connectedNodes(), isEmpty);

    final delegationDone = Completer<void>();
    currentCompletion = delegationDone;
    for (final tab in [
      {
        'tabId': 7,
        'identity': 'Lead app',
        'url': 'https://claude.ai/new',
        'capabilities': ['read_text', 'send_text', 'receive_task'],
        'taskDomains': ['general'],
      },
      {
        'tabId': 8,
        'identity': 'Helper app',
        'url': 'https://chatgpt.com/',
        'capabilities': ['read_text', 'send_text', 'receive_task'],
        'taskDomains': ['general'],
      },
    ]) {
      socket.add(jsonEncode({'type': 'REGISTER_TAB', 'payload': tab}));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    await server.runWorkflow({
      'nodes': const [],
      'edges': const [],
      'taskText': 'DELEGATE_TEST',
      'workflowId': 'delegation-flow',
    });
    await delegationDone.future.timeout(const Duration(seconds: 3));
    final delegatedRows = await db.tasks.forWorkflow('delegation-flow');
    final child =
        delegatedRows.where((task) => task.parentTaskId != null).single;
    expect(child.targetNode, 'tab-8');
    expect(child.parentTaskId, isNotNull);
    expect(child.status, 'completed');
    expect(
      messages.where((message) => message['type'] == 'SEND_TASK').any(
          (message) =>
              message['payload']['nodeId'] == 'tab-7' &&
              (message['payload']['text'] as String).contains('Connected app')),
      isTrue,
    );

    final researchDone = Completer<void>();
    currentCompletion = researchDone;
    socket.add(jsonEncode({
      'type': 'REGISTER_TAB',
      'payload': {
        'tabId': 9,
        'identity': 'Connected search tab',
        'url': 'https://www.google.com/search?q=bridge',
        'capabilities': ['read_text', 'receive_task', 'web_research'],
        'taskDomains': ['web_research'],
      },
    }));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await server.runWorkflow({
      'nodes': const [],
      'edges': const [],
      'taskText': 'Search the web for current Bridge examples',
      'workflowId': 'research-flow',
    });
    await researchDone.future.timeout(const Duration(seconds: 3));
    final researchTask = (await db.tasks.forWorkflow('research-flow')).single;
    expect(researchTask.targetNode, 'tab-9');
    expect(
        researchTask.result, contains('Visible connected-tab search result'));
    expect(researchTask.result, contains('https://example.com/source'));
    expect(researchTask.result, isNot(contains('Spoofed research result')));
    expect(
      rogueMessages
          .where((message) => message['type'] == 'WEB_RESEARCH_REQUEST'),
      isEmpty,
    );
    await socket.close();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await registry.connectedNodes(), isEmpty);
  });
}
