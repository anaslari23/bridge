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

void main() {
  late BridgeDatabase db;
  late EventBus bus;
  late WorkflowEngine engine;
  late Directory tmpDir;

  setUp(() async {
    db = BridgeDatabase(NativeDatabase.memory());
    bus = EventBus();
    final registry = NodeRegistry(db, bus);
    final pm = PermissionManager(db, bus);
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

    // Insert nodes with 'input' tier so approval is auto-granted in tests
    for (final id in ['n1', 'n2']) {
      await db.nodes.upsertNode(NodesCompanion.insert(
        id: id, name: id, kind: 'agent',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
      await (db.update(db.nodes)..where((t) => t.id.equals(id)))
          .write(const NodesCompanion(permissionTier: Value('input')));
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
}
