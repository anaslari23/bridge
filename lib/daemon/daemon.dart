import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:drift/native.dart';
import 'database.dart';
import 'event_bus.dart';
import 'node_registry.dart';
import 'permission_manager.dart';
import 'task_scheduler.dart';
import 'artifact_store.dart';
import 'workflow_engine.dart';
import 'ws_server.dart';
import 'recovery_manager.dart';
import 'workspace_store.dart';
import 'project_store.dart';
import 'security_policy.dart';

class Daemon {
  static const port = 7432;

  // Call from the main isolate
  static Future<({Stream<dynamic> events, SendPort send})> start() async {
    final fromDaemon = ReceivePort();
    final toMain = fromDaemon.sendPort;
    final events = StreamController<dynamic>();
    final supportDir = await getApplicationSupportDirectory();

    await Isolate.spawn(_daemonMain, (toMain, supportDir.path));

    // The daemon sends its SendPort as its first message
    final completer = Completer<SendPort>();
    fromDaemon.listen((msg) {
      if (msg is SendPort) {
        if (!completer.isCompleted) completer.complete(msg);
      } else {
        // A single-subscription controller buffers messages until the caller
        // attaches its listener after this handshake has returned. This keeps
        // startup events (workspace restore, auth token, recovery) lossless.
        events.add(msg);
      }
    });
    final daemonSend = await completer.future;

    return (events: events.stream, send: daemonSend);
  }

  static Future<void> _daemonMain((SendPort, String) args) async {
    final toMain = args.$1;
    final supportDirPath = args.$2;

    final fromMain = ReceivePort();
    toMain.send(fromMain.sendPort); // hand shake

    final dbPath = p.join(supportDirPath, 'BrigadeBridge', 'brigade.db');
    await Directory(p.dirname(dbPath)).create(recursive: true);
    final db = BridgeDatabase(NativeDatabase(File(dbPath)));
    final bus = EventBus();
    // Subscribe before recovery so startup interruptions are visible to the
    // overlay instead of being lost before the WebSocket server is ready.
    bus.stream.listen((event) => toMain.send(event));
    final workspaceStore = WorkspaceStore(db);
    final projectStore = ProjectStore(db);
    await projectStore.initialize();
    final authToken = await _localAuthToken(db);
    bus.publish(LocalAuthReady(authToken));
    Future<void> publishWorkspaceIndex() async {
      final items = await workspaceStore.list();
      bus.publish(WorkspaceIndexLoaded(
        items
            .map((workspace) => WorkspaceSummary(workspace.id, workspace.name,
                pinned: workspace.pinned))
            .toList(),
      ));
    }

    Future<void> publishProjectIndex() async {
      final active = await projectStore.activeProject();
      if (active != null) {
        bus.publish(ProjectIndexLoaded(await projectStore.list(), active.id));
      }
    }

    final registry = NodeRegistry(db, bus);
    final pm = PermissionManager(db, bus);
    pm.setAllowedDomains(SecurityPolicy.decode(
        await db.settingsDao.valueFor('allowed_domains')));
    final scheduler = TaskScheduler(db, bus);
    final artifactDir =
        Directory(p.join(supportDirPath, 'BrigadeBridge', 'artifacts'));
    await artifactDir.create(recursive: true);
    final store = ArtifactStore(artifactDir);
    final engine = WorkflowEngine(
      registry: registry,
      scheduler: scheduler,
      permissionManager: pm,
      artifactStore: store,
      bus: bus,
    );
    final recovery = RecoveryManager(db, bus);
    await recovery.replayIncomplete(engine);
    final workspaces = await workspaceStore.list();
    await publishWorkspaceIndex();
    await publishProjectIndex();
    if (workspaces.isNotEmpty) {
      final workspace = workspaces.reduce((a, b) {
        final aOpened = a.graph['_meta'] is Map
            ? (a.graph['_meta']['lastOpenedAt'] as num?)?.toInt() ?? 0
            : 0;
        final bOpened = b.graph['_meta'] is Map
            ? (b.graph['_meta']['lastOpenedAt'] as num?)?.toInt() ?? 0
            : 0;
        return aOpened >= bOpened ? a : b;
      });
      await workspaceStore.markOpened(workspace.id);
      final restored = await workspaceStore.load(workspace.id) ?? workspace;
      bus.publish(WorkspaceLoaded(restored.id, restored.name, restored.graph));
    }

    final server = WsServer(
      port: port,
      bus: bus,
      engine: engine,
      registry: registry,
      pm: pm,
      projectStore: projectStore,
      authToken: authToken,
    );
    await server.start();

    // Listen for commands from main isolate
    fromMain.listen((msg) async {
      if (msg is Map) {
        final type = msg['type'] as String?;
        if (type == 'STOP_ALL') {
          pm.cancelAll();
          engine.emergencyStop();
          server.broadcastControl('STOP_ALL');
        }
        if (type == 'CANCEL_WORKFLOW') server.cancelWorkflow();
        if (type == 'APPROVE_TASK') {
          pm.approve(msg['approvalId'] as String? ?? msg['taskId'] as String);
        }
        if (type == 'DENY_TASK') {
          pm.deny(msg['approvalId'] as String? ?? msg['taskId'] as String);
        }
        if (type == 'ALLOW_NODE') {
          unawaited(pm.allowForProject(
            approvalId: msg['approvalId'] as String? ?? msg['taskId'] as String,
            nodeId: msg['nodeId'] as String,
            capability: msg['capability'] as String,
            projectId: msg['projectId'] as String? ?? 'project-default',
          ));
        }
        if (type == 'ALLOW_FOR_PROJECT') {
          unawaited(pm.allowForProject(
            approvalId: msg['approvalId'] as String,
            nodeId: msg['nodeId'] as String,
            capability: msg['capability'] as String,
            projectId: msg['projectId'] as String,
          ));
        }
        if (type == 'SET_ALLOWED_DOMAINS') {
          final domains = msg['domains'] is List
              ? (msg['domains'] as List).whereType<String>().toList()
              : const <String>[];
          pm.setAllowedDomains(domains);
          await db.settingsDao.setValue('allowed_domains', pm.policy.encode());
          bus.publish(LogEntry('Domain allowlist updated'));
        }
        if (type == 'CREATE_PROJECT') {
          await projectStore.create(
              id: msg['id'] as String, name: msg['name'] as String);
          await projectStore.setActive(msg['id'] as String);
          await publishProjectIndex();
        }
        if (type == 'RENAME_PROJECT') {
          await projectStore.rename(msg['id'] as String, msg['name'] as String);
          await publishProjectIndex();
        }
        if (type == 'SET_ACTIVE_PROJECT') {
          await projectStore.setActive(msg['id'] as String);
          await publishProjectIndex();
        }
        if (type == 'SAVE_WORKSPACE') {
          workspaceStore.save(
            id: msg['id'] as String,
            name: msg['name'] as String,
            graph: Map<String, dynamic>.from(msg['graph'] as Map),
          );
          bus.publish(LogEntry('Workspace saved: ${msg['name']}'));
        }
        if (type == 'LOAD_WORKSPACE') {
          await workspaceStore.markOpened(msg['id'] as String);
          final workspace = await workspaceStore.load(msg['id'] as String);
          if (workspace != null) {
            bus.publish(
                WorkspaceLoaded(workspace.id, workspace.name, workspace.graph));
          }
        }
        if (type == 'CREATE_WORKSPACE') {
          await workspaceStore.save(
            id: msg['id'] as String,
            name: msg['name'] as String,
            graph: const <String, dynamic>{'nodes': [], 'edges': []},
          );
          await workspaceStore.markOpened(msg['id'] as String);
          await publishWorkspaceIndex();
        }
        if (type == 'DELETE_WORKSPACE') {
          await workspaceStore.delete(msg['id'] as String);
          await publishWorkspaceIndex();
        }
        if (type == 'RENAME_WORKSPACE') {
          await workspaceStore.rename(
              msg['id'] as String, msg['name'] as String);
          await publishWorkspaceIndex();
        }
        if (type == 'DUPLICATE_WORKSPACE') {
          await workspaceStore.duplicate(msg['sourceId'] as String,
              msg['id'] as String, msg['name'] as String);
          await publishWorkspaceIndex();
          final duplicate = await workspaceStore.load(msg['id'] as String);
          if (duplicate != null) {
            bus.publish(
                WorkspaceLoaded(duplicate.id, duplicate.name, duplicate.graph));
          }
        }
        if (type == 'PIN_WORKSPACE') {
          await workspaceStore.setPinned(
              msg['id'] as String, msg['pinned'] == true);
          await publishWorkspaceIndex();
        }
        if (type == 'CONNECT_OPENCODE') {
          try {
            final node = await server.connectOpenCode(
              serverUrl: msg['serverUrl'] as String,
              sessionId: msg['sessionId'] as String,
            );
            bus.publish(LogEntry('Connected OpenCode session ${node.detail}'));
          } catch (error) {
            bus.publish(LogEntry(
              'OpenCode connection failed: ${error.toString()}',
              severity: 'error',
            ));
          }
        }
        if (type == 'DISCONNECT_OPENCODE') {
          await server.disconnectOpenCode(msg['nodeId'] as String);
          bus.publish(LogEntry('Disconnected OpenCode session'));
        }
        if (type == 'RUN_WORKFLOW') {
          server.runWorkflow({
            'nodes': msg['nodes'] ?? [],
            'edges': msg['edges'] ?? [],
            'taskText': msg['taskText'] ?? '',
            if (msg['workflowId'] != null) 'workflowId': msg['workflowId'],
            if (msg['resumeCompleted'] == true) 'resumeCompleted': true,
            if (msg['attachments'] is List) 'attachments': msg['attachments'],
            if (msg['contextNodeIds'] is List)
              'contextNodeIds': msg['contextNodeIds'],
            if (msg['sourceNodeId'] != null)
              'sourceNodeId': msg['sourceNodeId'],
            if (msg['targetNodeId'] != null)
              'targetNodeId': msg['targetNodeId'],
          });
        }
      }
    });
  }

  static Future<String> _localAuthToken(BridgeDatabase db) async {
    final existing = await db.settingsDao.valueFor('local_auth_token');
    if (existing != null && existing.length >= 32) return existing;
    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256),
        growable: false);
    final token = base64UrlEncode(bytes).replaceAll('=', '');
    await db.settingsDao.setValue('local_auth_token', token);
    return token;
  }
}
