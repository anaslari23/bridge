import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brigade_bridge/daemon/database.dart';
import 'package:brigade_bridge/daemon/desktop_action_router.dart';
import 'package:brigade_bridge/daemon/event_bus.dart';
import 'package:brigade_bridge/daemon/permission_manager.dart';

void main() {
  test('read-only focus executes without approval', () async {
    final db = BridgeDatabase(NativeDatabase.memory());
    final bus = EventBus();
    addTearDown(() async {
      bus.dispose();
      await db.close();
    });
    await db.nodes.upsertNode(NodesCompanion.insert(
        id: 'desktop-1-0',
        name: 'Notes',
        kind: 'desktop',
        createdAt: DateTime.now().millisecondsSinceEpoch));
    final router = DesktopActionRouter(PermissionManager(db, bus),
        (action, node, value) async => action == 'focus_window');
    expect(await router.execute(nodeId: 'desktop-1-0', action: 'focus_window'),
        isTrue);
  });

  test('text input waits for explicit approval', () async {
    final db = BridgeDatabase(NativeDatabase.memory());
    final bus = EventBus();
    addTearDown(() async {
      bus.dispose();
      await db.close();
    });
    await db.nodes.upsertNode(NodesCompanion.insert(
        id: 'desktop-2-0',
        name: 'Editor',
        kind: 'desktop',
        createdAt: DateTime.now().millisecondsSinceEpoch));
    final permissions = PermissionManager(db, bus);
    final approval = Completer<String>();
    bus.stream.where((event) => event is ApprovalRequired).listen(
        (event) => approval.complete((event as ApprovalRequired).approvalId));
    var executed = false;
    final router =
        DesktopActionRouter(permissions, (action, node, value) async {
      executed = true;
      return true;
    });
    final result = router.execute(
        nodeId: 'desktop-2-0', action: 'set_focused_text', value: 'hello');
    final taskId = await approval.future;
    permissions.approve(taskId);
    expect(await result, isTrue);
    expect(executed, isTrue);
  });
}
