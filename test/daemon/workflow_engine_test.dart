import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brigade_bridge/daemon/database.dart';
import 'package:brigade_bridge/daemon/event_bus.dart';
import 'package:brigade_bridge/daemon/node_registry.dart';
import 'package:brigade_bridge/daemon/permission_manager.dart';
import 'package:brigade_bridge/daemon/task_scheduler.dart';
import 'package:brigade_bridge/daemon/artifact_store.dart';
import 'package:brigade_bridge/daemon/workflow_engine.dart';
import 'package:brigade_bridge/core/bridge_models.dart';
import 'package:drift/drift.dart';
import 'dart:io';
import 'dart:async';

void main() {
  late BridgeDatabase db;
  late EventBus bus;
  late WorkflowEngine engine;
  late PermissionManager pm;
  late Directory tmpDir;

  setUp(() async {
    db = BridgeDatabase(NativeDatabase.memory());
    bus = EventBus();
    final registry = NodeRegistry(db, bus);
    pm = PermissionManager(db, bus);
    tmpDir = await Directory.systemTemp.createTemp('bridge_test_');
    final store = ArtifactStore(tmpDir);
    final scheduler = TaskScheduler(db, bus);
    engine = WorkflowEngine(
      registry: registry,
      scheduler: scheduler,
      permissionManager: pm,
      artifactStore: store,
      bus: bus,
    );

    // Seed test-only project grants so ordinary text dispatch is authorized.
    for (final id in ['n1', 'n2']) {
      await db.nodes.upsertNode(NodesCompanion.insert(
        id: id,
        name: id,
        kind: 'agent',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
      await db.into(db.approvalGrants).insert(
            ApprovalGrantsCompanion.insert(
              projectId: 'project-default',
              nodeId: id,
              capability: 'send_text',
              grantedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
    }
  });
  tearDown(() async {
    await db.close();
    bus.dispose();
    await tmpDir.delete(recursive: true);
  });

  test('runs sequential workflow and passes output forward', () async {
    final received = <String>[];
    engine.sendToAdapter = (nodeId, text) async {
      received.add('$nodeId:$text');
      return 'result-from-$nodeId';
    };

    const nodes = [
      BridgeNode(id: 'n1', name: 'N1', kind: NodeKind.agent, detail: ''),
      BridgeNode(id: 'n2', name: 'N2', kind: NodeKind.agent, detail: ''),
    ];
    const edges = [NodeEdge('n1', 'n2')];

    await engine.run(nodes: nodes, edges: edges, taskText: 'initial');

    expect(received[0], 'n1:initial');
    expect(received[1], 'n2:result-from-n1');
  });

  test('explicit lead dispatch ignores display graph edges', () async {
    final received = <String>[];
    engine.sendToAdapter = (nodeId, text) async {
      received.add('$nodeId:$text');
      return 'done';
    };

    await engine.run(
      nodes: const [
        BridgeNode(id: 'n1', name: 'N1', kind: NodeKind.agent, detail: ''),
        BridgeNode(id: 'n2', name: 'N2', kind: NodeKind.agent, detail: ''),
      ],
      edges: const [NodeEdge('n2', 'n1')],
      taskText: 'Implement the feature',
      targetNodeId: 'n2',
    );

    expect(received, ['n2:Implement the feature']);
  });

  test('resumes after the last completed node without replaying it', () async {
    final received = <String>[];
    engine.sendToAdapter = (nodeId, text) async {
      received.add('$nodeId:$text');
      return 'result-from-$nodeId';
    };

    const edges = [NodeEdge('n1', 'n2')];
    const firstAttempt = [
      BridgeNode(id: 'n1', name: 'N1', kind: NodeKind.agent, detail: ''),
      BridgeNode(
          id: 'n2',
          name: 'N2',
          kind: NodeKind.agent,
          detail: '',
          health: 'unavailable'),
    ];
    await engine.run(
      nodes: firstAttempt,
      edges: edges,
      taskText: 'initial',
      workflowId: 'resume-flow',
    );
    expect(received, ['n1:initial']);

    const resumed = [
      const BridgeNode(id: 'n1', name: 'N1', kind: NodeKind.agent, detail: ''),
      const BridgeNode(id: 'n2', name: 'N2', kind: NodeKind.agent, detail: ''),
    ];
    await engine.run(
      nodes: resumed,
      edges: edges,
      taskText: 'initial',
      workflowId: 'resume-flow',
      resumeCompleted: true,
    );

    expect(received, ['n1:initial', 'n2:result-from-n1']);
  });

  test('injects explicitly selected read-only context before dispatch',
      () async {
    String? instruction;
    engine.sendToAdapter = (nodeId, text) async {
      instruction = text;
      return 'done';
    };
    engine.readContext = (nodeId) async => 'visible notes from $nodeId';

    await engine.run(
      nodes: const [
        BridgeNode(id: 'n1', name: 'N1', kind: NodeKind.agent, detail: '')
      ],
      edges: const [],
      taskText: 'Use the notes',
      contextNodeIds: const ['notes-tab'],
    );

    expect(instruction, contains('Use the notes'));
    expect(instruction, contains('[Brigade Bridge selected context]'));
    expect(instruction, contains('visible notes from notes-tab'));
  });

  test('ignores duplicate workflow IDs but preserves explicit resume',
      () async {
    var calls = 0;
    final logs = <String>[];
    bus.stream.listen((event) {
      if (event is LogEntry) logs.add(event.message);
    });
    engine.sendToAdapter = (nodeId, text) async {
      calls++;
      return 'result';
    };

    const nodes = [
      BridgeNode(id: 'n1', name: 'N1', kind: NodeKind.agent, detail: '')
    ];
    await engine.run(
        nodes: nodes,
        edges: const [],
        taskText: 'once',
        workflowId: 'idempotent-flow');
    await engine.run(
        nodes: nodes,
        edges: const [],
        taskText: 'once again',
        workflowId: 'idempotent-flow');
    await Future<void>.delayed(Duration.zero);

    expect(calls, 1);
    expect(logs.any((log) => log.contains('Workflow already exists')), isTrue);
  });

  test('emergency stop halts execution', () async {
    int callCount = 0;
    engine.sendToAdapter = (nodeId, text) async {
      callCount++;
      engine.emergencyStop();
      return 'r';
    };

    const nodes = [
      BridgeNode(id: 'n1', name: 'N1', kind: NodeKind.agent, detail: ''),
      BridgeNode(id: 'n2', name: 'N2', kind: NodeKind.agent, detail: ''),
    ];
    const edges = [NodeEdge('n1', 'n2')];

    await engine.run(nodes: nodes, edges: edges, taskText: 'go');
    expect(callCount, 1); // stopped after first node
  });

  test('terminal workflow requests command approval', () async {
    await db.nodes.upsertNode(NodesCompanion.insert(
      id: 'terminal',
      name: 'Terminal',
      kind: 'terminal',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    final approval = Completer<String>();
    bus.stream.listen((event) {
      if (event is ApprovalRequired && !approval.isCompleted) {
        approval.complete(event.task.id);
        pm.approve(event.approvalId);
      }
    });
    engine.sendToAdapter = (nodeId, text) async => 'command output';

    await engine.run(
      nodes: const [
        BridgeNode(
            id: 'terminal',
            name: 'Terminal',
            kind: NodeKind.terminal,
            detail: '')
      ],
      edges: const [],
      taskText: 'pwd',
    );

    expect(await approval.future, isNotEmpty);
  });

  test('file write approval includes a read-only preview', () async {
    await db.nodes.upsertNode(NodesCompanion.insert(
      id: 'files',
      name: 'Files',
      kind: 'file',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    final preview = Completer<String?>();
    bus.stream.listen((event) {
      if (event is ApprovalRequired && !preview.isCompleted) {
        preview.complete(event.preview);
        pm.approve(event.approvalId);
      }
    });
    engine.previewTask = (task) async => '--- a/notes.txt\n+++ b/notes.txt';
    engine.executeTask = (task) async => 'write complete';

    await engine.run(
      nodes: const [
        BridgeNode(id: 'files', name: 'Files', kind: NodeKind.file, detail: '')
      ],
      edges: const [],
      taskText: 'write notes.txt\nnew contents',
    );

    expect(await preview.future, contains('+++ b/notes.txt'));
  });

  test('pauses before dispatching to an unavailable node', () async {
    await db.nodes.upsertNode(NodesCompanion.insert(
      id: 'offline',
      name: 'Offline agent',
      kind: 'agent',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    await (db.update(db.nodes)..where((row) => row.id.equals('offline')))
        .write(const NodesCompanion(health: Value('unavailable')));
    var dispatched = false;
    final paused = Completer<String>();
    bus.stream.listen((event) {
      if (event is WorkflowPaused && !paused.isCompleted)
        paused.complete(event.health);
    });
    engine.executeTask = (task) async {
      dispatched = true;
      return 'unexpected';
    };

    await engine.run(
      nodes: const [
        BridgeNode(
            id: 'offline',
            name: 'Offline agent',
            kind: NodeKind.agent,
            detail: '',
            health: 'unavailable')
      ],
      edges: const [],
      taskText: 'do not send',
    );

    expect(dispatched, isFalse);
    expect(await paused.future, 'unavailable');
  });
}
