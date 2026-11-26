import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brigade_bridge/core/bridge_models.dart';
import 'package:brigade_bridge/core/node_adapter.dart';
import 'package:brigade_bridge/daemon/database.dart';
import 'package:brigade_bridge/daemon/delegation_manager.dart';
import 'package:brigade_bridge/daemon/event_bus.dart';
import 'package:brigade_bridge/daemon/node_registry.dart';
import 'package:brigade_bridge/daemon/permission_manager.dart';
import 'package:brigade_bridge/daemon/task_scheduler.dart';

void main() {
  late BridgeDatabase db;
  late EventBus bus;
  late NodeRegistry registry;
  late TaskScheduler scheduler;
  late PermissionManager permissions;
  late DelegationManager delegations;

  setUp(() async {
    db = BridgeDatabase(NativeDatabase.memory());
    bus = EventBus();
    registry = NodeRegistry(db, bus);
    scheduler = TaskScheduler(db, bus, retryDelay: Duration.zero);
    permissions = PermissionManager(db, bus);
    delegations = DelegationManager(
      registry: registry,
      scheduler: scheduler,
      permissions: permissions,
    );
    for (final node in [
      const BridgeNode(
        id: 'lead',
        name: 'Lead',
        kind: NodeKind.browser,
        detail: '',
        capabilities: ['receive_task'],
        health: 'connected',
      ),
      const BridgeNode(
        id: 'helper',
        name: 'Helper',
        kind: NodeKind.browser,
        detail: '',
        capabilities: ['receive_task'],
        health: 'connected',
      ),
      const BridgeNode(
        id: 'observer',
        name: 'Observer',
        kind: NodeKind.browser,
        detail: '',
        capabilities: ['read_text'],
        health: 'connected',
      ),
    ]) {
      await registry.register(node);
    }
    await db.into(db.approvalGrants).insert(
          ApprovalGrantsCompanion.insert(
            projectId: 'project-alpha',
            nodeId: 'helper',
            capability: 'send_text',
            grantedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  });

  tearDown(() async {
    bus.dispose();
    await db.close();
  });

  BridgeTask parent({String nodeId = 'lead', int depth = 0}) => BridgeTask(
        id: 'parent-task',
        sourceNodeId: 'user',
        targetNodeId: nodeId,
        instruction: 'finish the feature',
        projectId: 'project-alpha',
        workflowId: 'workflow-1',
        handoffDepth: depth,
      );

  test('creates one child and returns its result to the caller', () async {
    BridgeTask? child;
    final result = await delegations.request(
      parent: parent(),
      targetNodeId: 'helper',
      instruction: 'inspect the parser',
      runChild: (task) async {
        child = task;
        return 'parser handles the edge case';
      },
    );

    expect(result, 'parser handles the edge case');
    expect(child?.parentTaskId, 'parent-task');
    expect(child?.projectId, 'project-alpha');
    expect(child?.sourceNodeId, 'lead');
    expect(child?.targetNodeId, 'helper');
    expect(child?.handoffDepth, 1);
    final row = await (db.select(db.tasks)
          ..where((task) => task.id.equals(child!.id)))
        .getSingle();
    expect(row.status, 'completed');
  });

  test('rejects self, disconnected, and unsupported targets', () async {
    await expectLater(
      delegations.request(
        parent: parent(),
        targetNodeId: 'lead',
        instruction: 'same app',
        runChild: (_) async => 'unused',
      ),
      throwsA(isA<AdapterDispatchException>()),
    );
    await expectLater(
      delegations.request(
        parent: parent(),
        targetNodeId: 'missing',
        instruction: 'unknown app',
        runChild: (_) async => 'unused',
      ),
      throwsA(isA<AdapterDispatchException>()),
    );
    await expectLater(
      delegations.request(
        parent: parent(),
        targetNodeId: 'observer',
        instruction: 'observer cannot receive tasks',
        runChild: (_) async => 'unused',
      ),
      throwsA(isA<AdapterDispatchException>()),
    );
  });

  test('rejects empty instructions and handoff depth eight', () async {
    await expectLater(
      delegations.request(
        parent: parent(),
        targetNodeId: 'helper',
        instruction: '  ',
        runChild: (_) async => 'unused',
      ),
      throwsA(isA<AdapterDispatchException>()),
    );
    await expectLater(
      delegations.request(
        parent: parent(depth: 8),
        targetNodeId: 'helper',
        instruction: 'too deep',
        runChild: (_) async => 'unused',
      ),
      throwsA(isA<AdapterDispatchException>()),
    );
  });
}
