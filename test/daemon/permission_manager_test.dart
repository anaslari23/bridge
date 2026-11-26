import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brigade_bridge/daemon/database.dart';
import 'package:brigade_bridge/daemon/event_bus.dart';
import 'package:brigade_bridge/daemon/permission_manager.dart';
import 'package:brigade_bridge/core/bridge_models.dart';

BridgeDatabase memDb() => BridgeDatabase(NativeDatabase.memory());

void main() {
  late BridgeDatabase db;
  late EventBus bus;
  late PermissionManager pm;

  setUp(() async {
    db = memDb();
    bus = EventBus();
    pm = PermissionManager(db, bus);
    // Insert a read_only node
    await db.nodes.upsertNode(NodesCompanion.insert(
      id: 'n1',
      name: 'Codex',
      kind: 'agent',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    await db.nodes.upsertNode(NodesCompanion.insert(
      id: 'n2',
      name: 'Claude',
      kind: 'agent',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
  });
  tearDown(() async {
    await db.close();
    bus.dispose();
  });

  test('read_text allowed on read_only node without approval', () async {
    final task = BridgeTask(
        id: 't1', sourceNodeId: 'x', targetNodeId: 'n1', instruction: 'test');
    final ok = await pm.checkAndRequest(
        approvalId: task.id,
        nodeId: 'n1',
        capability: 'read_text',
        task: task,
        projectId: task.projectId);
    expect(ok, isTrue);
    // No ApprovalRequired event
    final events = <DaemonEvent>[];
    bus.stream.listen(events.add);
    await Future.delayed(Duration.zero);
    expect(events.whereType<ApprovalRequired>().length, 0);
  });

  test('send_text on read_only node emits ApprovalRequired', () async {
    final events = <DaemonEvent>[];
    bus.stream.listen(events.add);

    final task = BridgeTask(
        id: 't2', sourceNodeId: 'x', targetNodeId: 'n1', instruction: 'hello');

    // Don't await — it will pause waiting for approval
    final futureResult = pm.checkAndRequest(
        approvalId: task.id,
        nodeId: 'n1',
        capability: 'send_text',
        task: task,
        projectId: task.projectId);
    await Future.delayed(const Duration(milliseconds: 50));

    expect(events.whereType<ApprovalRequired>().length, 1);
    final waiting = events.whereType<TaskStatusChanged>().single;
    expect(waiting.status, TaskStatus.waitingForApproval);
    expect(waiting.task?.targetNodeId, 'n1');
    pm.approve('t2');

    final result = await futureResult;
    expect(result, isTrue);
  });

  test('deny cancels waiting task', () async {
    final task = BridgeTask(
        id: 't3', sourceNodeId: 'x', targetNodeId: 'n1', instruction: 'hello');
    final futureResult = pm.checkAndRequest(
        approvalId: task.id,
        nodeId: 'n1',
        capability: 'send_text',
        task: task,
        projectId: task.projectId);
    await Future.delayed(const Duration(milliseconds: 50));
    pm.deny('t3');
    final result = await futureResult;
    expect(result, isFalse);
  });

  test('window capture uses read_screen permission', () async {
    final task = BridgeTask(
        id: 't4',
        sourceNodeId: 'x',
        targetNodeId: 'n1',
        instruction: 'capture');
    final futureResult = pm.checkAction('n1', 'capture_window', task);
    await Future.delayed(const Duration(milliseconds: 50));
    pm.approve('t4');
    expect(await futureResult, isTrue);
  });

  test('blocks open_link until its HTTPS domain is allowlisted', () async {
    final task = BridgeTask(
        id: 't-domain',
        sourceNodeId: 'x',
        targetNodeId: 'n1',
        instruction: 'open https://example.com/docs');

    expect(
        await pm.checkAndRequest(
            approvalId: task.id,
            nodeId: 'n1',
            capability: 'open_link',
            task: task,
            projectId: task.projectId),
        isFalse);
    expect((await db.audit.recent()).first.decision, 'blocked_domain');

    pm.setAllowedDomains(const ['example.com']);
    final approval = pm.checkAndRequest(
        approvalId: task.id,
        nodeId: 'n1',
        capability: 'open_link',
        task: task,
        projectId: task.projectId);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    pm.approve(task.id);
    expect(await approval, isTrue);
  });

  test('cancelAll resolves every pending approval as denied', () async {
    final first = BridgeTask(
        id: 't5', sourceNodeId: 'x', targetNodeId: 'n1', instruction: 'one');
    final second = BridgeTask(
        id: 't6', sourceNodeId: 'x', targetNodeId: 'n1', instruction: 'two');
    final firstResult = pm.checkAndRequest(
        approvalId: first.id,
        nodeId: 'n1',
        capability: 'send_text',
        task: first,
        projectId: first.projectId);
    final secondResult = pm.checkAndRequest(
        approvalId: second.id,
        nodeId: 'n1',
        capability: 'send_text',
        task: second,
        projectId: second.projectId);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    pm.cancelAll();

    expect(await firstResult, isFalse);
    expect(await secondResult, isFalse);
  });

  test('always allow is scoped to the project and does not elevate node tier',
      () async {
    final task = BridgeTask(
        id: 't7', sourceNodeId: 'x', targetNodeId: 'n1', instruction: 'hello');
    final futureResult = pm.checkAndRequest(
        approvalId: task.id,
        nodeId: 'n1',
        capability: 'send_text',
        task: task,
        projectId: task.projectId);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await pm.allowForProject(
        approvalId: task.id,
        nodeId: 'n1',
        capability: 'send_text',
        projectId: task.projectId);

    expect(await futureResult, isTrue);
    final node = await (db.select(db.nodes)
          ..where((row) => row.id.equals('n1')))
        .getSingle();
    expect(node.permissionTier, 'read_only');
    expect((await db.audit.recent()).map((entry) => entry.decision),
        contains('always_allow_for_project'));
  });

  test('project grant applies only to its exact project, app, and capability',
      () async {
    final task = BridgeTask(
        id: 't-scope',
        sourceNodeId: 'x',
        targetNodeId: 'n1',
        instruction: 'hello');
    final approval = pm.checkAndRequest(
      approvalId: 'approval-a',
      nodeId: 'n1',
      capability: 'send_text',
      task: task,
      projectId: 'project-a',
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await pm.allowForProject(
      approvalId: 'approval-a',
      nodeId: 'n1',
      capability: 'send_text',
      projectId: 'project-a',
    );
    expect(await approval, isTrue);

    Future<bool> check(String approvalId, String projectId, String nodeId,
            String capability) =>
        pm.checkAndRequest(
          approvalId: approvalId,
          nodeId: nodeId,
          capability: capability,
          task: BridgeTask(
              id: 'task-$approvalId',
              sourceNodeId: 'x',
              targetNodeId: nodeId,
              instruction: 'hello'),
          projectId: projectId,
        );

    expect(await check('same-scope', 'project-a', 'n1', 'send_text'), isTrue);
    final otherProject = check('other-project', 'project-b', 'n1', 'send_text');
    final otherApp = check('other-app', 'project-a', 'n2', 'send_text');
    final otherCapability =
        check('other-capability', 'project-a', 'n1', 'click');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    pm.deny('other-project');
    pm.deny('other-app');
    pm.deny('other-capability');
    expect(await otherProject, isFalse);
    expect(await otherApp, isFalse);
    expect(await otherCapability, isFalse);
  });

  test('separate approval IDs for one task resolve independently', () async {
    final task = BridgeTask(
        id: 'same-task',
        sourceNodeId: 'x',
        targetNodeId: 'n1',
        instruction: 'hello');
    final first = pm.checkAndRequest(
        approvalId: 'approval-1',
        nodeId: 'n1',
        capability: 'send_text',
        task: task,
        projectId: 'project-default');
    final second = pm.checkAndRequest(
        approvalId: 'approval-2',
        nodeId: 'n1',
        capability: 'send_text',
        task: task,
        projectId: 'project-default');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    pm.approve('approval-1');
    pm.deny('approval-2');
    expect(await first, isTrue);
    expect(await second, isFalse);
  });
}
