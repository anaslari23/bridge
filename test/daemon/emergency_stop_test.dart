import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brigade_bridge/daemon/database.dart';
import 'package:brigade_bridge/daemon/event_bus.dart';
import 'package:brigade_bridge/daemon/node_registry.dart';
import 'package:brigade_bridge/daemon/permission_manager.dart';
import 'package:brigade_bridge/daemon/task_scheduler.dart';
import 'package:brigade_bridge/daemon/artifact_store.dart';
import 'package:brigade_bridge/daemon/workflow_engine.dart';
import 'dart:io';

void main() {
  test('emergencyStop emits LogEntry with severity=emergency', () async {
    final db = BridgeDatabase(NativeDatabase.memory());
    final bus = EventBus();
    final tmp = await Directory.systemTemp.createTemp();
    final engine = WorkflowEngine(
      registry: NodeRegistry(db, bus),
      scheduler: TaskScheduler(db, bus),
      permissionManager: PermissionManager(db, bus),
      artifactStore: ArtifactStore(tmp),
      bus: bus,
    );

    final events = <DaemonEvent>[];
    bus.stream.listen(events.add);

    engine.emergencyStop();
    await Future.delayed(Duration.zero);

    final emergencyLogs = events
        .whereType<LogEntry>()
        .where((e) => e.severity == 'emergency')
        .toList();
    expect(emergencyLogs.length, 1);

    await db.close();
    bus.dispose();
    await tmp.delete(recursive: true);
  });
}
