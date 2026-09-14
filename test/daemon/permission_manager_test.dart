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
      id: 'n1', name: 'Codex', kind: 'agent',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
  });
  tearDown(() async {
    await db.close();
    bus.dispose();
  });

  test('read_text allowed on read_only node without approval', () async {
    final task = BridgeTask(
        id: 't1', sourceNodeId: 'x', targetNodeId: 'n1',
        instruction: 'test');
    final ok = await pm.checkAndRequest('n1', 'read_text', task);
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
        id: 't2', sourceNodeId: 'x', targetNodeId: 'n1',
        instruction: 'hello');

    // Don't await — it will pause waiting for approval
    final futureResult = pm.checkAndRequest('n1', 'send_text', task);
    await Future.delayed(const Duration(milliseconds: 50));

    expect(events.whereType<ApprovalRequired>().length, 1);
    pm.approve('t2');

    final result = await futureResult;
    expect(result, isTrue);
  });

  test('deny cancels waiting task', () async {
    final task = BridgeTask(
        id: 't3', sourceNodeId: 'x', targetNodeId: 'n1',
        instruction: 'hello');
    final futureResult = pm.checkAndRequest('n1', 'send_text', task);
    await Future.delayed(const Duration(milliseconds: 50));
    pm.deny('t3');
    final result = await futureResult;
    expect(result, isFalse);
  });
}
