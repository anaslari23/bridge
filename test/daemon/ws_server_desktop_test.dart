import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brigade_bridge/core/bridge_models.dart';
import 'package:brigade_bridge/daemon/artifact_store.dart';
import 'package:brigade_bridge/daemon/database.dart';
import 'package:brigade_bridge/daemon/event_bus.dart';
import 'package:brigade_bridge/daemon/node_registry.dart';
import 'package:brigade_bridge/daemon/permission_manager.dart';
import 'package:brigade_bridge/daemon/project_store.dart';
import 'package:brigade_bridge/daemon/task_scheduler.dart';
import 'package:brigade_bridge/daemon/workflow_engine.dart';
import 'package:brigade_bridge/daemon/ws_server.dart';

void main() {
  test('does not control a desktop app without an explicit connector',
      () async {
    final db = BridgeDatabase(NativeDatabase.memory());
    final bus = EventBus();
    final artifactDir =
        await Directory.systemTemp.createTemp('bridge-desktop-task-');
    addTearDown(() async {
      bus.dispose();
      await db.close();
      await artifactDir.delete(recursive: true);
    });

    final registry = NodeRegistry(db, bus);
    final projectStore = ProjectStore(db);
    await projectStore.initialize();
    final permissions = PermissionManager(db, bus);
    final scheduler = TaskScheduler(db, bus, maxAttempts: 1);
    final engine = WorkflowEngine(
      registry: registry,
      scheduler: scheduler,
      permissionManager: permissions,
      artifactStore: ArtifactStore(artifactDir),
      bus: bus,
    );
    final server = WsServer(
      port: 17433,
      bus: bus,
      engine: engine,
      registry: registry,
      pm: permissions,
      projectStore: projectStore,
    );
    final approvalSubscription = bus.stream.listen((event) {
      if (event is ApprovalRequired) permissions.approve(event.approvalId);
    });
    addTearDown(approvalSubscription.cancel);

    await registry.register(const BridgeNode(
      id: 'desktop-1-0',
      name: 'Antigravity IDE',
      kind: NodeKind.desktop,
      detail: 'Editor',
      processId: 123,
      windowId: 'desktop-1-0',
      adapterId: 'macos-accessibility',
      adapterVersion: 'v1',
      capabilities: ['set_focused_text'],
      health: 'connected',
    ));

    await server.runWorkflow({
      'nodes': [
        {
          'id': 'desktop-1-0',
          'name': 'Antigravity IDE',
          'kind': 'desktop',
          'detail': 'Editor',
        }
      ],
      'edges': [],
      'taskText': 'Prepare this file',
      'workflowId': 'desktop-workflow-1',
    });

    final tasks = await db.tasks.forWorkflow('desktop-workflow-1');
    expect(tasks, isEmpty,
        reason:
            'a persisted desktop node without a live explicit connector is ineligible');

    await expectLater(
      server.runWorkflow({'projectId': 'unknown-project'}),
      throwsFormatException,
    );
  });
}
