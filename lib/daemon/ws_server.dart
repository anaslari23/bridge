import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../core/bridge_models.dart';
import 'event_bus.dart';
import 'node_registry.dart';
import 'permission_manager.dart';
import 'workflow_engine.dart';

class WsServer {
  WsServer({
    required this.port,
    required this.bus,
    required this.engine,
    required this.registry,
    required this.pm,
  });

  final int port;
  final EventBus bus;
  final WorkflowEngine engine;
  final NodeRegistry registry;
  final PermissionManager pm;

  HttpServer? _server;
  final _clients = <WebSocket>[];

  // Extension adapter callbacks
  final _taskCompleters = <String, Completer<String?>>{};

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server!.transform(WebSocketTransformer()).listen(_onClient);

    // Forward daemon events to all connected clients
    bus.stream.listen(_broadcast);
  }

  void _onClient(WebSocket ws) {
    _clients.add(ws);
    ws.listen(
      (raw) => _handleMessage(ws, raw as String),
      onDone: () => _clients.remove(ws),
    );
  }

  void _handleMessage(WebSocket ws, String raw) {
    final msg = jsonDecode(raw) as Map<String, dynamic>;
    final type = msg['type'] as String;
    final payload = msg['payload'] as Map<String, dynamic>? ?? {};

    switch (type) {
      case 'REGISTER_TAB':
        final node = BridgeNode(
          id: 'tab-${payload['tabId']}',
          name: payload['identity'] as String? ?? payload['title'] as String,
          kind: NodeKind.browser,
          detail: payload['url'] as String,
          tabId: payload['tabId'] as int?,
          url: payload['url'] as String?,
        );
        registry.register(node);

      case 'TASK_RESULT':
        final taskId = payload['taskId'] as String;
        final output = payload['output'] as String?;
        _taskCompleters[taskId]?.complete(output);

      case 'ERROR':
        final taskId = payload['taskId'] as String;
        _taskCompleters[taskId]?.complete(null);

      case 'LIST_NODES':
        registry.allNodes().then((nodes) {
          ws.add(jsonEncode({
            'type': 'NODE_LIST',
            'payload': {'nodes': nodes.map((n) => {'id': n.id, 'name': n.name}).toList()},
          }));
        });

      case 'APPROVE_TASK':
        pm.approve(payload['taskId'] as String);

      case 'DENY_TASK':
        pm.deny(payload['taskId'] as String);

      case 'STOP_ALL':
        engine.emergencyStop();

      case 'RUN_WORKFLOW':
        runWorkflow(payload);
    }
  }

  Future<void> runWorkflow(Map<String, dynamic> payload) async {
    final rawNodes = payload['nodes'] as List;
    final rawEdges = payload['edges'] as List;
    final taskText = payload['taskText'] as String;

    final nodes = rawNodes.map((n) => BridgeNode(
      id: n['id'] as String,
      name: n['name'] as String,
      kind: NodeKind.values.firstWhere((k) => k.name == (n['kind'] ?? 'agent')),
      detail: n['detail'] as String? ?? '',
      tabId: n['tabId'] as int?,
      url: n['url'] as String?,
    )).toList();

    final edges = rawEdges
        .map((e) => NodeEdge(e['from'] as String, e['to'] as String))
        .toList();

    engine.sendToAdapter = (nodeId, text) {
      final completer = Completer<String?>();
      final taskId = 'ext-${DateTime.now().millisecondsSinceEpoch}';
      _taskCompleters[taskId] = completer;
      _broadcast(jsonEncode({
        'type': 'SEND_TASK',
        'payload': {'nodeId': nodeId, 'taskId': taskId, 'text': text},
      }));
      return completer.future.timeout(const Duration(seconds: 120),
          onTimeout: () => null);
    };

    await engine.run(nodes: nodes, edges: edges, taskText: taskText);
  }

  void _broadcast(dynamic data) {
    final msg = data is String ? data : _eventToJson(data);
    if (msg == null) return;
    for (final ws in List.of(_clients)) {
      try { ws.add(msg); } catch (_) {}
    }
  }

  String? _eventToJson(DaemonEvent event) {
    if (event is LogEntry) {
      return jsonEncode({
        'type': 'LOG_ENTRY',
        'payload': {'message': event.message, 'severity': event.severity},
      });
    }
    if (event is TaskStatusChanged) {
      return jsonEncode({
        'type': 'TASK_STATUS_CHANGED',
        'payload': {'taskId': event.taskId, 'status': event.status.name},
      });
    }
    if (event is ApprovalRequired) {
      return jsonEncode({
        'type': 'APPROVAL_REQUIRED',
        'payload': {
          'taskId': event.task.id,
          'instruction': event.task.instruction,
          'sourceName': event.sourceName,
          'targetName': event.targetName,
        },
      });
    }
    if (event is NodeRegistered) {
      return jsonEncode({
        'type': 'NODE_REGISTERED',
        'payload': {'id': event.node.id, 'name': event.node.name},
      });
    }
    return null;
  }

  Future<void> stop() async {
    for (final ws in _clients) { try { await ws.close(); } catch (_) {} }
    await _server?.close();
  }
}
