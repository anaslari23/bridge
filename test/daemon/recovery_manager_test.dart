import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brigade_bridge/daemon/database.dart';
import 'package:brigade_bridge/daemon/event_bus.dart';
import 'package:brigade_bridge/daemon/artifact_store.dart';
import 'package:brigade_bridge/daemon/node_registry.dart';
import 'package:brigade_bridge/daemon/permission_manager.dart';
import 'package:brigade_bridge/daemon/recovery_manager.dart';
import 'package:brigade_bridge/daemon/task_scheduler.dart';
import 'package:brigade_bridge/daemon/workflow_engine.dart';

void main() {
  test('marks interrupted tasks failed and emits recovery signal', () async {
    final db = BridgeDatabase(NativeDatabase.memory());
    final bus = EventBus();
    final events = <DaemonEvent>[];
    final subscription = bus.stream.listen(events.add);
    addTearDown(subscription.cancel);
    addTearDown(bus.dispose);
    addTearDown(db.close);

    await db.tasks.upsertTask(TasksCompanion.insert(
      id: 'interrupted-1',
      sourceNode: 'codex',
      targetNode: 'claude',
      instruction: 'Continue the task',
      createdAt: 1,
      updatedAt: 1,
      status: const Value('working'),
    ));

    final engine = WorkflowEngine(
      registry: NodeRegistry(db, bus),
      scheduler: TaskScheduler(db, bus),
      permissionManager: PermissionManager(db, bus),
      artifactStore: ArtifactStore(
          Directory.systemTemp.createTempSync('bridge-recovery-test-')),
      bus: bus,
    );
    await RecoveryManager(db, bus).replayIncomplete(engine);

    final row = (await db.select(db.tasks).get()).single;
    expect(row.status, 'failed');
    expect(row.error, contains('Interrupted'));
    final recovery = events.whereType<RecoveryRequired>().single;
    expect(recovery.taskIds, ['interrupted-1']);
  });
}
