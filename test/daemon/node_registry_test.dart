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

  test('preserves live adapter identity and health metadata', () async {
    await registry.register(const BridgeNode(
      id: 'tab-7',
      name: 'Claude',
      kind: NodeKind.browser,
      detail: 'https://claude.ai/new',
      tabId: 7,
      url: 'https://claude.ai/new',
      adapterId: 'claude-web',
      adapterVersion: 'v2',
      capabilities: ['read_text', 'send_text'],
      processId: 123,
      windowId: 'window-7',
    ));
    await registry.updateHealth('tab-7', 'healthy');

    final node = (await registry.allNodes()).single;
    expect(node.adapterId, 'claude-web');
    expect(node.adapterVersion, 'v2');
    expect(node.capabilities, contains('send_text'));
    expect(node.processId, 123);
    expect(node.windowId, 'window-7');
    expect(node.health, 'healthy');
  });

  test('connectedNodes excludes persisted nodes with no live connection',
      () async {
    await registry.register(const BridgeNode(
      id: 'tab-live',
      name: 'Live',
      kind: NodeKind.browser,
      detail: 'https://example.com',
      health: 'connected',
    ));
    await registry.register(const BridgeNode(
      id: 'tab-gone',
      name: 'Gone',
      kind: NodeKind.browser,
      detail: 'https://example.org',
      health: 'connected',
    ));
    await registry.updateHealth('tab-gone', 'unavailable');

    final connected = await registry.connectedNodes();
    expect(connected.map((node) => node.id), ['tab-live']);
  });

  test('remove deletes the paired node from live and persisted registry',
      () async {
    await registry.register(const BridgeNode(
      id: 'tab-7',
      name: 'Claude',
      kind: NodeKind.browser,
      detail: 'https://claude.ai',
      health: 'connected',
    ));

    await registry.remove('tab-7');

    expect(await registry.connectedNodes(), isEmpty);
    expect(await registry.allNodes(), isEmpty);
  });
}
