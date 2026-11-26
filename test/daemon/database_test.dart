import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brigade_bridge/daemon/database.dart';

BridgeDatabase openInMemory() => BridgeDatabase(NativeDatabase.memory());

void main() {
  late BridgeDatabase db;
  setUp(() => db = openInMemory());
  tearDown(() => db.close());

  test('insert and retrieve node', () async {
    await db.nodes.upsertNode(NodesCompanion.insert(
      id: 'n1',
      name: 'Codex',
      kind: 'agent',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    final all = await db.nodes.allNodes();
    expect(all.length, 1);
    expect(all.first.name, 'Codex');
    expect(all.first.permissionTier, 'read_only');
  });

  test('task status update', () async {
    await db.tasks.upsertTask(TasksCompanion.insert(
      id: 't1',
      sourceNode: 'n1',
      targetNode: 'n2',
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
        nodeId: 'n1',
        capability: 'send_text',
        decision: 'approved',
        taskId: 't1');
    final log = await db.audit.recent();
    expect(log.length, 1);
    expect(log.first.capability, 'send_text');
  });

  test('persists local adapter settings', () async {
    await db.settingsDao.setValue('terminal_directory', '/tmp/brigade-project');
    expect(await db.settingsDao.valueFor('terminal_directory'),
        '/tmp/brigade-project');
    await db.settingsDao.setValue('terminal_directory', '/tmp/updated-project');
    expect(await db.settingsDao.valueFor('terminal_directory'),
        '/tmp/updated-project');
  });

  test('migrates schema v2 tasks without losing rows or inventing grants',
      () async {
    await db.close();
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('''
        CREATE TABLE tasks (
          id TEXT NOT NULL PRIMARY KEY,
          workflow_id TEXT,
          source_node TEXT NOT NULL,
          target_node TEXT NOT NULL,
          instruction TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'created',
          result TEXT,
          error TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      raw.execute('''
        INSERT INTO tasks (id, source_node, target_node, instruction,
          created_at, updated_at) VALUES ('legacy-task', 'user', 'app', 'keep', 1, 1)
      ''');
      raw.execute('PRAGMA user_version = 2');
    });
    final upgraded = BridgeDatabase(executor);
    addTearDown(upgraded.close);

    final legacy = await upgraded.select(upgraded.tasks).getSingle();
    expect(legacy.id, 'legacy-task');
    expect(legacy.projectId, isNull);
    expect(legacy.parentTaskId, isNull);
    expect(legacy.handoffDepth, 0);
    expect(await upgraded.select(upgraded.approvalGrants).get(), isEmpty);
  });
}
