import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../core/bridge_models.dart';
import '../core/bridge_protocol.dart';
import '../core/node_adapter.dart';
import 'event_bus.dart';
import 'node_registry.dart';
import 'permission_manager.dart';
import 'project_store.dart';
import 'lead_router.dart';
import 'delegation_manager.dart';
import 'codex_connector.dart';
import 'opencode_connector.dart';
import 'secret_redactor.dart';
import 'workflow_engine.dart';

class WsServer {
  static const _maxMessageCharacters = 2 * 1024 * 1024;

  WsServer({
    required this.port,
    required this.bus,
    required this.engine,
    required this.registry,
    required this.pm,
    this.projectStore,
    this.authToken,
  });

  final int port;
  final EventBus bus;
  final WorkflowEngine engine;
  final NodeRegistry registry;
  final PermissionManager pm;
  final ProjectStore? projectStore;
  final LeadRouter leadRouter = const LeadRouter();
  late final DelegationManager _delegations = DelegationManager(
    registry: registry,
    scheduler: engine.scheduler,
    permissions: pm,
  );
  final String? authToken;

  HttpServer? _server;
  Timer? _healthTimer;
  final _clients = <WebSocket>[];
  final _authenticated = <WebSocket, bool>{};
  final _nodeOwners = <String, WebSocket>{};
  final _registeredUrls = <String, String>{};
  final _registeredWindowIds = <String, String>{};
  final _lastSeen = <String, DateTime>{};
  final _reportedHealth = <String, String>{};

  // Extension adapter callbacks
  final _taskCompleters = <String, Completer<String?>>{};
  final _taskOwners = <String, WebSocket>{};
  final _bridgeTaskExternalIds = <String, String>{};
  final _bridgeTaskTargets = <String, String>{};
  final _inspectionCompleters = <String, Completer<String?>>{};
  final _inspectionOwners = <String, WebSocket>{};
  final _researchCompleters = <String, Completer<Map<String, dynamic>>>{};
  final _researchOwners = <String, WebSocket>{};
  OpenCodeConnector? _openCodeConnector;
  final _openCodeTaskOwners = <String, OpenCodeConnector>{};
  CodexConnector? _codexConnector;
  final _codexTaskOwners = <String, CodexConnector>{};

  Future<BridgeNode> connectCodex({
    required String serverUrl,
    required String threadId,
  }) async {
    final current = _codexConnector;
    if (current != null) {
      if (current.threadId != threadId) {
        throw StateError('Disconnect the current Codex thread first');
      }
      await disconnectCodex(current.nodeId);
    }

    final connector = CodexConnector(
      serverUrl: serverUrl,
      threadId: threadId,
      onNotice: (message) => bus.publish(LogEntry(message, severity: 'warning')),
    );
    try {
      final node = await connector.connect();
      _codexConnector = connector;
      await registry.register(node);
      unawaited(connector.closed.then((_) async {
        if (identical(_codexConnector, connector)) {
          await registry.updateHealth(node.id, 'unavailable');
        }
      }));
      return node;
    } catch (_) {
      await connector.close();
      rethrow;
    }
  }

  Future<void> disconnectCodex(String nodeId) async {
    final connector = _codexConnector;
    if (connector == null || nodeId != connector.nodeId) return;
    _codexConnector = null;
    for (final taskId in _codexTaskOwners.entries
        .where((entry) => entry.value == connector)
        .map((entry) => entry.key)
        .toList()) {
      try {
        await connector.cancelTask(taskId);
      } catch (_) {
        // Closing the connection below fails any remaining request.
      }
      _codexTaskOwners.remove(taskId);
    }
    await connector.close();
    await registry.remove(nodeId);
  }

  Future<BridgeNode> connectOpenCode({
    required String serverUrl,
    required String sessionId,
  }) async {
    final current = _openCodeConnector;
    if (current != null) {
      if (current.sessionId != sessionId) {
        throw StateError('Disconnect the current OpenCode session first');
      }
      await disconnectOpenCode('opencode:${current.sessionId}');
    }

    final connector = OpenCodeConnector(
      serverUrl: serverUrl,
      sessionId: sessionId,
    );
    try {
      final node = await connector.connect();
      _openCodeConnector = connector;
      await registry.register(node);
      return node;
    } catch (_) {
      await connector.close();
      rethrow;
    }
  }

  Future<void> disconnectOpenCode(String nodeId) async {
    final connector = _openCodeConnector;
    if (connector == null || nodeId != 'opencode:${connector.sessionId}') {
      return;
    }
    _openCodeConnector = null;
    for (final taskId in _openCodeTaskOwners.entries
        .where((entry) => entry.value == connector)
        .map((entry) => entry.key)
        .toList()) {
      try {
        await connector.cancelTask(taskId);
      } catch (_) {
        // Closing the session connection below will fail any remaining request.
      }
      _openCodeTaskOwners.remove(taskId);
    }
    await connector.close();
    await registry.remove(nodeId);
  }

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server!.transform(WebSocketTransformer()).listen(_onClient);
    engine.cancelTask ??= (_) async => broadcastControl('STOP_ALL');

    // Forward daemon events to all connected clients
    bus.stream.listen(_broadcast);
    _healthTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _checkHealth());
  }

  void cancelWorkflow() {
    pm.cancelAll();
    engine.cancelActive();
    broadcastControl('STOP_ALL');
  }

  void _onClient(WebSocket ws) {
    _clients.add(ws);
    _authenticated[ws] = authToken == null;
    ws.listen(
      (raw) => _handleMessage(ws, raw),
      onDone: () async {
        _clients.remove(ws);
        _authenticated.remove(ws);
        for (final taskId in _taskOwners.entries
            .where((entry) => entry.value == ws)
            .map((entry) => entry.key)
            .toList()) {
          _taskOwners.remove(taskId);
          _clearBridgeTaskExternalId(taskId);
          final completer = _taskCompleters.remove(taskId);
          if (completer != null && !completer.isCompleted) {
            completer.completeError(AdapterDispatchException(
              'Adapter connection closed while handling task',
              retryable: true,
            ));
          }
        }
        for (final requestId in _inspectionOwners.entries
            .where((entry) => entry.value == ws)
            .map((entry) => entry.key)
            .toList()) {
          _inspectionOwners.remove(requestId);
          final completer = _inspectionCompleters.remove(requestId);
          if (completer != null && !completer.isCompleted) {
            completer.complete(null);
          }
        }
        for (final requestId in _researchOwners.entries
            .where((entry) => entry.value == ws)
            .map((entry) => entry.key)
            .toList()) {
          _researchOwners.remove(requestId);
          final completer = _researchCompleters.remove(requestId);
          if (completer != null && !completer.isCompleted) {
            completer.completeError(AdapterDispatchException(
              'Browser disconnected during web research',
              retryable: true,
            ));
          }
        }
        final owned = _nodeOwners.entries
            .where((entry) => entry.value == ws)
            .map((entry) => entry.key)
            .toList();
        for (final nodeId in owned) {
          _nodeOwners.remove(nodeId);
          _registeredUrls.remove(nodeId);
          _registeredWindowIds.remove(nodeId);
          _lastSeen.remove(nodeId);
          await registry.updateHealth(nodeId, 'unavailable');
          _reportedHealth[nodeId] = 'unavailable';
        }
      },
    );
  }

  void _handleMessage(WebSocket ws, dynamic raw) {
    if (raw is! String || raw.length > _maxMessageCharacters) {
      _sendProtocolError(ws, 'Message is not valid UTF-8 text or is too large');
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        _sendProtocolError(ws, 'Message must be a JSON object');
        return;
      }
      final msg = Map<String, dynamic>.from(decoded);
      final type = msg['type'];
      if (type is! String || type.isEmpty) {
        _sendProtocolError(ws, 'Message type is required');
        return;
      }
      final rawPayload = msg['payload'];
      final payload = rawPayload is Map
          ? Map<String, dynamic>.from(rawPayload)
          : <String, dynamic>{};

      if (type != 'AUTHENTICATE' && _authenticated[ws] != true) {
        _sendProtocolError(
            ws, 'Authenticate with the local pairing token first');
        return;
      }

      switch (type) {
        case 'AUTHENTICATE':
          final token = payload['token'];
          if (authToken == null || token is! String || token != authToken) {
            _sendProtocolError(ws, 'Local pairing token was rejected');
            unawaited(ws.close(WebSocketStatus.policyViolation,
                'Local pairing token rejected'));
            break;
          }
          _authenticated[ws] = true;
          ws.add(jsonEncode({'type': 'AUTHENTICATED', 'payload': {}}));

        case 'REGISTER_TAB':
          final tabId = payload['tabId'];
          final url = payload['url'] as String?;
          if (tabId is! int || url == null || !url.startsWith('https://')) {
            ws.add(jsonEncode({
              'type': 'REGISTRATION_REJECTED',
              'payload': {'reason': 'Invalid tab identity'}
            }));
            break;
          }
          final node = BridgeNode(
            id: 'tab-$tabId',
            name: payload['identity'] as String? ??
                payload['title'] as String? ??
                Uri.parse(url).host,
            kind: NodeKind.browser,
            detail: url,
            tabId: tabId,
            url: url,
            adapterId: payload['adapterId'] as String?,
            adapterVersion: payload['adapterVersion'] as String?,
            windowId: payload['windowId']?.toString(),
            processId: payload['processId'] is int
                ? payload['processId'] as int
                : null,
            health: 'connected',
            capabilities: payload['capabilities'] is List
                ? (payload['capabilities'] as List).whereType<String>().toList()
                : const ['read_text', 'send_text'],
            taskDomains: payload['taskDomains'] is List
                ? (payload['taskDomains'] as List).whereType<String>().toList()
                : const ['general'],
          );
          _nodeOwners[node.id] = ws;
          _registeredUrls[node.id] = url;
          final windowId = payload['windowId']?.toString();
          if (windowId == null) {
            _registeredWindowIds.remove(node.id);
          } else {
            _registeredWindowIds[node.id] = windowId;
          }
          _lastSeen[node.id] = DateTime.now();
          _reportedHealth[node.id] = 'connected';
          registry.register(node);

        case 'HEARTBEAT':
          final tabId = payload['tabId'];
          final nodeId = 'tab-$tabId';
          if (tabId is! int || _nodeOwners[nodeId] != ws) break;
          final url = payload['url'] as String?;
          if (url == null || !url.startsWith('https://')) break;
          _lastSeen[nodeId] = DateTime.now();
          final expectedWindowId = _registeredWindowIds[nodeId];
          final reportedWindowId = payload['windowId']?.toString();
          if (_registeredUrls[nodeId] != url ||
              (expectedWindowId != null &&
                  expectedWindowId != reportedWindowId)) {
            if (_reportedHealth[nodeId] != 'degraded') {
              _reportedHealth[nodeId] = 'degraded';
              registry.updateHealth(nodeId, 'degraded');
              bus.publish(LogEntry(
                'Browser tab identity changed; waiting for re-registration',
                severity: 'warning',
              ));
            }
            break;
          }
          if (_reportedHealth[nodeId] != 'connected') {
            _reportedHealth[nodeId] = 'connected';
            registry.updateHealth(nodeId, 'connected');
          }

        case 'ADAPTER_HEALTH':
          final tabId = payload['tabId'];
          final nodeId = payload['nodeId'] as String? ??
              (tabId is int ? 'tab-$tabId' : null);
          final health = payload['health'] as String?;
          const allowed = {
            'connected',
            'degraded',
            'unavailable',
            'requires_update',
          };
          if (nodeId == null ||
              health == null ||
              !allowed.contains(health) ||
              _nodeOwners[nodeId] != ws) break;
          _reportedHealth[nodeId] = health;
          registry.updateHealth(nodeId, health);

        case 'TAB_REMOVED':
          final tabId = payload['tabId'];
          if (tabId is! int) break;
          final nodeId = 'tab-$tabId';
          if (_nodeOwners[nodeId] != ws) break;
          _nodeOwners.remove(nodeId);
          _registeredUrls.remove(nodeId);
          _registeredWindowIds.remove(nodeId);
          _lastSeen.remove(nodeId);
          _reportedHealth[nodeId] = 'unavailable';
          _failResearchForNodeOwner(ws, 'Connected search tab was removed');
          unawaited(registry.remove(nodeId));

        case 'TASK_RESULT':
          final taskId = payload['taskId'] as String;
          if (_taskOwners[taskId] != ws) break;
          _taskOwners.remove(taskId);
          _clearBridgeTaskExternalId(taskId);
          final output = payload['output'] as String?;
          final completer = _taskCompleters.remove(taskId);
          if (completer != null && !completer.isCompleted)
            completer.complete(output);

        case 'ERROR':
          final taskId = payload['taskId'] as String;
          if (_taskOwners[taskId] != ws) break;
          _taskOwners.remove(taskId);
          _clearBridgeTaskExternalId(taskId);
          final completer = _taskCompleters.remove(taskId);
          if (completer != null && !completer.isCompleted) {
            completer.completeError(AdapterDispatchException(
              payload['output'] as String? ?? 'Adapter reported an error',
              retryable: payload['retryable'] == true,
            ));
          }

        case 'TASK_CANCELLED':
          final taskId = payload['taskId'] as String;
          if (_taskOwners[taskId] != ws) break;
          _taskOwners.remove(taskId);
          _clearBridgeTaskExternalId(taskId);
          final completer = _taskCompleters.remove(taskId);
          if (completer != null && !completer.isCompleted)
            completer.complete(null);

        case 'TAB_INSPECTION':
          final requestId =
              payload['requestId'] as String? ?? payload['taskId'] as String;
          if (_inspectionOwners[requestId] != ws) break;
          _inspectionOwners.remove(requestId);
          final completer = _inspectionCompleters.remove(requestId);
          if (completer != null && !completer.isCompleted)
            completer.complete(payload['output'] as String?);

        case 'WEB_RESEARCH_RESULT':
          final requestId = payload['requestId'] as String?;
          if (requestId == null || _researchOwners[requestId] != ws) break;
          _researchOwners.remove(requestId);
          final completer = _researchCompleters.remove(requestId);
          if (completer != null && !completer.isCompleted) {
            completer.complete({
              'query': payload['query'] as String? ?? '',
              'pageText': payload['pageText'] as String? ?? '',
              'sources': payload['sources'] is List
                  ? (payload['sources'] as List)
                      .whereType<Map>()
                      .map((source) => Map<String, dynamic>.from(source))
                      .where((source) =>
                          source['title'] is String && source['url'] is String)
                      .take(30)
                      .toList()
                  : const <Map<String, dynamic>>[],
            });
          }

        case 'LIST_NODES':
          registry.connectedNodes().then((nodes) {
            ws.add(jsonEncode({
              'type': 'NODE_LIST',
              'payload': {
                'nodes': nodes.map((n) => {'id': n.id, 'name': n.name}).toList()
              },
            }));
          });

        case 'APPROVE_TASK':
          pm.approve(
              payload['approvalId'] as String? ?? payload['taskId'] as String);

        case 'ALLOW_NODE':
          unawaited(pm.allowForProject(
            approvalId:
                payload['approvalId'] as String? ?? payload['taskId'] as String,
            nodeId: payload['nodeId'] as String,
            capability: payload['capability'] as String,
            projectId: payload['projectId'] as String? ?? 'project-default',
          ));

        case 'ALLOW_FOR_PROJECT':
          unawaited(pm.allowForProject(
            approvalId: payload['approvalId'] as String,
            nodeId: payload['nodeId'] as String,
            capability: payload['capability'] as String,
            projectId: payload['projectId'] as String,
          ));

        case 'DENY_TASK':
          pm.deny(
              payload['approvalId'] as String? ?? payload['taskId'] as String);

        case 'STOP_ALL':
          pm.cancelAll();
          engine.emergencyStop();
          broadcastControl('STOP_ALL');

        case 'CANCEL_WORKFLOW':
          cancelWorkflow();

        case 'CANCEL_TASK':
          final taskId = payload['taskId'] as String?;
          if (taskId != null) {
            final completer = _taskCompleters.remove(taskId);
            _taskOwners.remove(taskId);
            if (completer != null && !completer.isCompleted)
              completer.complete(null);
            broadcastControl('CANCEL_TASK', {'taskId': taskId});
          }

        case 'RUN_WORKFLOW':
          unawaited(_runWorkflowSafely(ws, payload));
      }
    } catch (error) {
      _sendProtocolError(
          ws, 'Invalid message: ${SecretRedactor.redact(error.toString())}');
      bus.publish(
          LogEntry('Rejected malformed adapter message', severity: 'warning'));
    }
  }

  Future<void> _runWorkflowSafely(
      WebSocket ws, Map<String, dynamic> payload) async {
    try {
      await runWorkflow(payload);
    } catch (error) {
      _sendProtocolError(ws,
          'Workflow request failed: ${SecretRedactor.redact(error.toString())}');
      bus.publish(LogEntry('Workflow request failed', severity: 'error'));
    }
  }

  void _sendProtocolError(WebSocket ws, String reason) {
    try {
      ws.add(jsonEncode({
        'type': 'PROTOCOL_ERROR',
        'payload': {'reason': reason},
      }));
    } catch (_) {}
  }

  Future<String?> inspectTab(String nodeId) {
    final requestId = 'inspect-${DateTime.now().microsecondsSinceEpoch}';
    final completer = Completer<String?>();
    final owner = _nodeOwners[nodeId];
    if (owner == null) return Future<String?>.value(null);
    _inspectionCompleters[requestId] = completer;
    _inspectionOwners[requestId] = owner;
    _sendToNode(
        nodeId,
        jsonEncode({
          'type': 'INSPECT_TAB',
          'payload': {'nodeId': nodeId, 'requestId': requestId}
        }));
    return completer.future.timeout(const Duration(seconds: 10), onTimeout: () {
      _inspectionCompleters.remove(requestId);
      _inspectionOwners.remove(requestId);
      return null;
    });
  }

  Future<void> runWorkflow(Map<String, dynamic> payload) async {
    final projectId =
        payload['projectId'] as String? ?? ProjectStore.defaultProjectId;
    if (projectStore != null && !await projectStore!.contains(projectId)) {
      throw FormatException('Unknown project: $projectId');
    }
    // A new explicit dispatch is also the user's intent to resume after an
    // emergency stop.
    engine.reset();
    final taskText = payload['taskText'] as String;
    final workflowId = payload['workflowId'] as String?;
    final overrideNodeId = payload['targetNodeId'] as String?;
    final resumeCompleted = payload['resumeCompleted'] == true;
    final attachments = payload['attachments'] is List
        ? (payload['attachments'] as List)
            .map(BridgeAttachment.fromJson)
            .whereType<BridgeAttachment>()
            .toList()
        : const <BridgeAttachment>[];
    final contextNodeIds = payload['contextNodeIds'] is List
        ? (payload['contextNodeIds'] as List).whereType<String>().toList()
        : const <String>[];

    final lead = leadRouter.selectLead(
      taskText: taskText,
      connectedNodes: await registry.connectedNodes(),
      overrideNodeId: overrideNodeId,
    );
    if (lead == null) {
      bus.publish(LogEntry(
        overrideNodeId == null
            ? 'No connected app is eligible for this task; connect an app or choose a lead'
            : 'The selected app is unavailable or cannot receive tasks',
        severity: 'warning',
      ));
      return;
    }
    final nodes = [lead];
    const edges = <NodeEdge>[];

    engine.sendToAdapter = (nodeId, text) {
      return _sendRawTaskToAdapter(nodeId, text);
    };
    engine.dispatchTask = _sendTaskToAdapter;
    engine.cancelTask = (task) async => _cancelBridgeTask(task.id);
    engine.readContext = (nodeId) async {
      final node = nodes.firstWhere((candidate) => candidate.id == nodeId,
          orElse: () => const BridgeNode(
              id: '', name: '', kind: NodeKind.agent, detail: ''));
      if (node.id.isEmpty || node.kind != NodeKind.browser) return null;
      return inspectTab(nodeId);
    };
    await engine.run(
      nodes: nodes,
      edges: edges,
      taskText: taskText,
      projectId: projectId,
      targetNodeId: lead.id,
      workflowId: workflowId,
      resumeCompleted: resumeCompleted,
      attachments: attachments,
      contextNodeIds: contextNodeIds,
    );
  }

  Future<String?> _sendTaskToAdapter(BridgeTask task) async {
    final node = (await registry.connectedNodes())
        .where((candidate) => candidate.id == task.targetNodeId);
    if (node.isNotEmpty &&
        node.first.capabilities.contains('web_research') &&
        TaskDomainClassifier.classify(task.instruction)
            .contains('web_research')) {
      final result =
          await _requestWebResearch(task.targetNodeId, task.instruction);
      final sources = (result['sources'] as List<Map<String, dynamic>>)
          .map((source) => '- ${source['title']} — ${source['url']}')
          .join('\n');
      return '''Search request: ${result['query']}
Current connected tab content:
${result['pageText']}
Sources:
${sources.isEmpty ? '(No source links were visible on the connected page.)' : sources}''';
    }
    var prompt = BridgeProtocol.taskPrompt(task.instruction);
    var handoffs = 0;
    while (true) {
      final isOpenCode = task.targetNodeId.startsWith('opencode:');
      final isCodex = task.targetNodeId.startsWith(CodexConnector.nodeIdPrefix);
      if (isOpenCode && task.attachments.isNotEmpty) {
        throw AdapterDispatchException(
            'OpenCode session connector does not support file attachments');
      }
      if (isCodex && task.attachments.isNotEmpty) {
        throw AdapterDispatchException(
            'Codex thread connector does not support file attachments');
      }
      final output = isOpenCode
          ? await _sendTaskToOpenCode(task, prompt)
          : isCodex
              ? await _sendTaskToCodex(task, prompt)
              : await _sendTaskOnce(task, prompt,
                  includeAttachments: handoffs == 0);
      final directive =
          output == null ? null : BridgeProtocol.parseDelegation(output);
      if (directive == null) return output;
      if (handoffs >= 8) {
        throw AdapterDispatchException('Maximum delegation depth reached');
      }
      final childResult = await _delegations.request(
        parent: task,
        targetNodeId: directive.targetNodeId,
        instruction: directive.instruction,
        runChild: _sendTaskToAdapter,
        cancelChild: _cancelBridgeTask,
      );
      final childMatches = (await registry.connectedNodes())
          .where((node) => node.id == directive.targetNodeId);
      final childName = childMatches.isEmpty
          ? directive.targetNodeId
          : childMatches.first.name;
      prompt = BridgeProtocol.continuationPrompt(
        instruction: task.instruction,
        appName: childName,
        result: childResult ?? '',
      );
      handoffs++;
    }
  }

  Future<String?> _sendTaskToOpenCode(BridgeTask task, String prompt) async {
    final connector = _openCodeConnector;
    if (connector == null ||
        task.targetNodeId != 'opencode:${connector.sessionId}') {
      throw AdapterDispatchException('OpenCode session is unavailable');
    }
    _openCodeTaskOwners[task.id] = connector;
    try {
      return await connector.sendTask(task, prompt: prompt);
    } catch (error) {
      if (error is OpenCodeSessionBusyException) {
        throw AdapterDispatchException(
          'OpenCode session already has active work; try again when it finishes',
        );
      }
      await registry.updateHealth(task.targetNodeId, 'unavailable');
      throw AdapterDispatchException(
        'OpenCode session request failed: ${SecretRedactor.redact(error.toString())}',
      );
    } finally {
      if (_openCodeTaskOwners[task.id] == connector) {
        _openCodeTaskOwners.remove(task.id);
      }
    }
  }

  Future<String?> _sendTaskToCodex(BridgeTask task, String prompt) async {
    final connector = _codexConnector;
    if (connector == null || task.targetNodeId != connector.nodeId) {
      throw AdapterDispatchException('Codex thread is unavailable');
    }
    _codexTaskOwners[task.id] = connector;
    try {
      return await connector.sendTask(task, prompt: prompt);
    } catch (error) {
      if (error is CodexSessionBusyException) {
        throw AdapterDispatchException(
          'Codex thread already has active work; try again when it finishes',
        );
      }
      await registry.updateHealth(task.targetNodeId, 'unavailable');
      throw AdapterDispatchException(
        'Codex thread request failed: ${SecretRedactor.redact(error.toString())}',
      );
    } finally {
      if (_codexTaskOwners[task.id] == connector) {
        _codexTaskOwners.remove(task.id);
      }
    }
  }

  Future<String?> _sendTaskOnce(
    BridgeTask task,
    String text, {
    required bool includeAttachments,
  }) async {
    final attachments = includeAttachments
        ? await _prepareAttachmentPayload(task.attachments)
        : const <Map<String, dynamic>>[];
    final completer = Completer<String?>();
    final taskId = 'ext-${DateTime.now().microsecondsSinceEpoch}';
    final owner = _nodeOwners[task.targetNodeId];
    if (owner == null) {
      throw AdapterDispatchException('Target adapter is unavailable',
          retryable: true);
    }
    if (_reportedHealth[task.targetNodeId] != 'connected') {
      throw AdapterDispatchException(
        'Target browser identity changed; re-register the tab before dispatching',
        retryable: false,
      );
    }
    _taskCompleters[taskId] = completer;
    _taskOwners[taskId] = owner;
    _bridgeTaskExternalIds[task.id] = taskId;
    _bridgeTaskTargets[task.id] = task.targetNodeId;
    _sendToNode(
        task.targetNodeId,
        jsonEncode({
          'type': 'SEND_TASK',
          'payload': {
            'nodeId': task.targetNodeId,
            'taskId': taskId,
            'text': text,
            'contextNodeIds': task.contextNodeIds,
            // Do not expose local paths to browser content. The daemon retains
            // the path for local adapters and sends only safe attachment metadata
            // across the browser boundary until an approved upload is performed.
            'attachments': attachments,
          },
        }));
    return completer.future.timeout(const Duration(seconds: 120),
        onTimeout: () {
      _taskCompleters.remove(taskId);
      _taskOwners.remove(taskId);
      if (_bridgeTaskExternalIds[task.id] == taskId) {
        _bridgeTaskExternalIds.remove(task.id);
        _bridgeTaskTargets.remove(task.id);
      }
      throw AdapterDispatchException('Adapter response timed out',
          retryable: true);
    });
  }

  Future<void> _cancelBridgeTask(String bridgeTaskId) async {
    final openCode = _openCodeTaskOwners.remove(bridgeTaskId);
    if (openCode != null) {
      await openCode.cancelTask(bridgeTaskId);
      return;
    }
    final codex = _codexTaskOwners.remove(bridgeTaskId);
    if (codex != null) {
      await codex.cancelTask(bridgeTaskId);
      return;
    }
    final externalTaskId = _bridgeTaskExternalIds.remove(bridgeTaskId);
    final nodeId = _bridgeTaskTargets.remove(bridgeTaskId);
    if (externalTaskId == null || nodeId == null) return;
    _taskCompleters.remove(externalTaskId)?.complete(null);
    _taskOwners.remove(externalTaskId);
    final owner = _nodeOwners[nodeId];
    if (owner == null) return;
    owner.add(jsonEncode({
      'type': 'CANCEL_TASK',
      'payload': {'taskId': externalTaskId},
    }));
  }

  Future<Map<String, dynamic>> _requestWebResearch(
      String nodeId, String query) async {
    final owner = _nodeOwners[nodeId];
    final connected =
        (await registry.connectedNodes()).where((node) => node.id == nodeId);
    if (owner == null ||
        connected.isEmpty ||
        !connected.first.capabilities.contains('web_research')) {
      throw AdapterDispatchException('Connected search tab is unavailable');
    }
    final requestId = 'research-${DateTime.now().microsecondsSinceEpoch}';
    final completer = Completer<Map<String, dynamic>>();
    _researchCompleters[requestId] = completer;
    _researchOwners[requestId] = owner;
    _sendToNode(
      nodeId,
      jsonEncode({
        'type': 'WEB_RESEARCH_REQUEST',
        'payload': {
          'nodeId': nodeId,
          'requestId': requestId,
          'query': query,
        },
      }),
    );
    return completer.future.timeout(const Duration(seconds: 30), onTimeout: () {
      _researchCompleters.remove(requestId);
      _researchOwners.remove(requestId);
      throw AdapterDispatchException('Connected tab research timed out',
          retryable: true);
    });
  }

  void _failResearchForNodeOwner(WebSocket owner, String message) {
    final requests = _researchOwners.entries
        .where((entry) => entry.value == owner)
        .map((entry) => entry.key)
        .toList();
    for (final requestId in requests) {
      _researchOwners.remove(requestId);
      final completer = _researchCompleters.remove(requestId);
      if (completer != null && !completer.isCompleted) {
        completer
            .completeError(AdapterDispatchException(message, retryable: true));
      }
    }
  }

  void _clearBridgeTaskExternalId(String externalTaskId) {
    final matches = _bridgeTaskExternalIds.entries
        .where((entry) => entry.value == externalTaskId)
        .map((entry) => entry.key)
        .toList();
    for (final bridgeTaskId in matches) {
      _bridgeTaskExternalIds.remove(bridgeTaskId);
      _bridgeTaskTargets.remove(bridgeTaskId);
    }
  }

  Future<String?> _sendRawTaskToAdapter(String nodeId, String text) {
    final completer = Completer<String?>();
    final taskId = 'ext-${DateTime.now().microsecondsSinceEpoch}';
    final owner = _nodeOwners[nodeId];
    if (owner == null) {
      return Future<String?>.error(AdapterDispatchException(
        'Target adapter is unavailable',
        retryable: true,
      ));
    }
    if (_reportedHealth[nodeId] != 'connected') {
      return Future<String?>.error(AdapterDispatchException(
        'Target browser identity changed; re-register the tab before dispatching',
        retryable: false,
      ));
    }
    _taskCompleters[taskId] = completer;
    _taskOwners[taskId] = owner;
    _sendToNode(
      nodeId,
      jsonEncode({
        'type': 'SEND_TASK',
        'payload': {'nodeId': nodeId, 'taskId': taskId, 'text': text},
      }),
    );
    return completer.future.timeout(const Duration(seconds: 120),
        onTimeout: () {
      _taskCompleters.remove(taskId);
      _taskOwners.remove(taskId);
      throw AdapterDispatchException('Adapter response timed out',
          retryable: true);
    });
  }

  Future<List<Map<String, dynamic>>> _prepareAttachmentPayload(
      List<BridgeAttachment> attachments) async {
    const maxFileBytes = 8 * 1024 * 1024;
    const maxTotalBytes = 20 * 1024 * 1024;
    var totalBytes = 0;
    final result = <Map<String, dynamic>>[];
    for (final attachment in attachments) {
      final file = File(attachment.path);
      if (!file.isAbsolute || !await file.exists()) {
        throw AdapterDispatchException(
            'Attachment is no longer available: ${attachment.name}');
      }
      final size = await file.length();
      if (size > maxFileBytes || totalBytes + size > maxTotalBytes) {
        throw AdapterDispatchException(
            'Attachment size limit exceeded: ${attachment.name}');
      }
      final digest = await sha256.bind(file.openRead()).first;
      if (attachment.contentHash != null &&
          attachment.contentHash != digest.toString()) {
        throw AdapterDispatchException(
            'Attachment changed since selection: ${attachment.name}');
      }
      final bytes = await file.readAsBytes();
      totalBytes += bytes.length;
      result.add({
        'name': attachment.name,
        'sizeBytes': bytes.length,
        'mimeType': attachment.mimeType,
        'contentHash': digest.toString(),
        'dataBase64': base64Encode(bytes),
      });
    }
    return result;
  }

  void _broadcast(dynamic data) {
    final msg = data is String ? data : _eventToJson(data);
    if (msg == null) return;
    for (final ws in List.of(_clients)) {
      if (_authenticated[ws] != true) continue;
      try {
        ws.add(msg);
      } catch (_) {}
    }
  }

  void _sendToNode(String nodeId, String message) {
    final owner = _nodeOwners[nodeId];
    if (owner == null) return;
    try {
      owner.add(message);
    } catch (_) {
      // The socket close handler will mark the node unavailable.
    }
  }

  void broadcastControl(String type, [Map<String, dynamic>? payload]) {
    _broadcast(
        jsonEncode({'type': type, 'payload': payload ?? <String, dynamic>{}}));
  }

  void _checkHealth() {
    final now = DateTime.now();
    for (final entry in _lastSeen.entries.toList()) {
      if (_reportedHealth[entry.key] == 'requires_update') continue;
      final age = now.difference(entry.value);
      final next = age > const Duration(seconds: 45)
          ? 'unavailable'
          : age > const Duration(seconds: 25)
              ? 'degraded'
              : 'connected';
      if (_reportedHealth[entry.key] != next) {
        _reportedHealth[entry.key] = next;
        registry.updateHealth(entry.key, next);
      }
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
        'payload': {
          'taskId': event.taskId,
          'status': event.status.name,
          if (event.result != null) 'result': event.result,
          if (event.error != null) 'error': event.error,
          if (event.task != null) ...{
            'workflowId': event.task!.workflowId,
            'sourceNodeId': event.task!.sourceNodeId,
            'targetNodeId': event.task!.targetNodeId,
            'instruction': event.task!.instruction,
          },
        },
      });
    }
    if (event is TaskRetrying) {
      return jsonEncode({
        'type': 'TASK_RETRYING',
        'payload': {
          'taskId': event.taskId,
          'attempt': event.attempt,
          'maxAttempts': event.maxAttempts,
          'error': event.error,
        },
      });
    }
    if (event is WorkflowPaused) {
      return jsonEncode({
        'type': 'WORKFLOW_PAUSED',
        'payload': {
          'nodeId': event.nodeId,
          'nodeName': event.nodeName,
          'health': event.health,
        },
      });
    }
    if (event is RecoveryRequired) {
      return jsonEncode({
        'type': 'RECOVERY_REQUIRED',
        'payload': {'taskIds': event.taskIds},
      });
    }
    if (event is ArtifactCreated) {
      return jsonEncode({
        'type': 'ARTIFACT_CREATED',
        'payload': {
          'taskId': event.taskId,
          'path': event.path,
          'sizeBytes': event.sizeBytes,
          'contentHash': event.contentHash,
          'mimeType': event.mimeType,
        },
      });
    }
    if (event is ApprovalRequired) {
      return jsonEncode({
        'type': 'APPROVAL_REQUIRED',
        'payload': {
          'taskId': event.task.id,
          'approvalId': event.approvalId,
          'projectId': event.projectId,
          'instruction': event.task.instruction,
          'sourceName': event.sourceName,
          'targetName': event.targetName,
          'capability': event.capability,
          if (event.preview != null) 'preview': event.preview,
        },
      });
    }
    if (event is NodeRegistered) {
      return jsonEncode({
        'type': 'NODE_REGISTERED',
        'payload': {'id': event.node.id, 'name': event.node.name},
      });
    }
    if (event is NodeRemoved) {
      return jsonEncode({
        'type': 'NODE_REMOVED',
        'payload': {'id': event.nodeId},
      });
    }
    if (event is WorkspaceLoaded) {
      return jsonEncode({
        'type': 'WORKSPACE_LOADED',
        'payload': {'id': event.id, 'name': event.name, 'graph': event.graph},
      });
    }
    if (event is WorkspaceIndexLoaded) {
      return jsonEncode({
        'type': 'WORKSPACE_INDEX',
        'payload': {
          'workspaces': event.workspaces
              .map((w) => {'id': w.id, 'name': w.name, 'pinned': w.pinned})
              .toList()
        },
      });
    }
    return null;
  }

  Future<void> stop() async {
    _healthTimer?.cancel();
    _healthTimer = null;
    final openCode = _openCodeConnector;
    _openCodeConnector = null;
    await openCode?.close();
    final codex = _codexConnector;
    _codexConnector = null;
    await codex?.close();
    for (final ws in _clients) {
      try {
        await ws.close();
      } catch (_) {}
    }
    await _server?.close();
  }
}
