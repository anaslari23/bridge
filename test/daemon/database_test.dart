import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brigade_bridge/daemon/database.dart';

BridgeDatabase openInMemory() =>
    BridgeDatabase(NativeDatabase.memory());

void main() {
  late BridgeDatabase db;
  setUp(() => db = openInMemory());
  tearDown(() => db.close());

  test('insert and retrieve node', () async {
    await db.nodes.upsertNode(NodesCompanion.insert(
      id: 'n1', name: 'Codex', kind: 'agent',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    final all = await db.nodes.allNodes();
    expect(all.length, 1);
    expect(all.first.name, 'Codex');
    expect(all.first.permissionTier, 'read_only');
  });

  test('task status update', () async {
    await db.tasks.upsertTask(TasksCompanion.insert(
      id: 't1', sourceNode: 'n1', targetNode: 'n2',
      instruction: 'test',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
    await db.tasks.updateStatus('t1', 'completed', result: 'done');
    final tasks = await db.tasks.incompleteTasks();
    expect(tasks.isEmpty, isTrue);
  });

  test('audit log records entries', () async {
    await db.audit.log(
        nodeId: 'n1', capability: 'send_text',
        decision: 'approved', taskId: 't1');
    final log = await db.audit.recent();
    expect(log.length, 1);
    expect(log.first.capability, 'send_text');
  });
}
