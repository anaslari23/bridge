import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brigade_bridge/daemon/database.dart';
import 'package:brigade_bridge/daemon/event_bus.dart';
import 'package:brigade_bridge/daemon/node_registry.dart';
import 'package:brigade_bridge/core/bridge_models.dart';

void main() {
  late BridgeDatabase db;
  late EventBus bus;
  late NodeRegistry registry;

  setUp(() {
    db = BridgeDatabase(NativeDatabase.memory());
    bus = EventBus();
    registry = NodeRegistry(db, bus);
  });
  tearDown(() async {
    await db.close();
    bus.dispose();
  });

  test('register emits NodeRegistered event', () async {
    final events = <DaemonEvent>[];
    bus.stream.listen(events.add);

    await registry.register(const BridgeNode(
        id: 'c1', name: 'Codex', kind: NodeKind.agent, detail: 'Tab 2'));

    await Future.delayed(Duration.zero);
    expect(events.whereType<NodeRegistered>().length, 1);
  });

  test('allNodes returns registered nodes', () async {
    await registry.register(const BridgeNode(
        id: 'c1', name: 'Codex', kind: NodeKind.agent, detail: 'Tab 2'));
    final nodes = await registry.allNodes();
    expect(nodes.length, 1);
    expect(nodes.first.name, 'Codex');
  });
}
