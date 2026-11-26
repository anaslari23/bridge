import 'package:drift/drift.dart';
import '../core/bridge_models.dart';
import 'database.dart';
import 'event_bus.dart';

class NodeRegistry {
  NodeRegistry(this._db, this._bus);
  final BridgeDatabase _db;
  final EventBus _bus;
  final _liveNodes = <String, BridgeNode>{};
  final _health = <String, String>{};

  Future<void> register(BridgeNode node) async {
    _liveNodes[node.id] = node;
    _health[node.id] = node.health;
    await _db.nodes.upsertNode(NodesCompanion(
      id: Value(node.id),
      name: Value(node.name),
      kind: Value(node.kind.name),
      url: Value(node.url),
      tabId: Value(node.tabId),
      health: Value(node.health),
      createdAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
    _bus.publish(NodeRegistered(node));
    _bus.publish(LogEntry('Node registered: ${node.name}'));
  }

  Future<List<BridgeNode>> connectedNodes() async => (await allNodes())
      .where((node) =>
          _liveNodes.containsKey(node.id) &&
          (_health[node.id] ?? node.health) == 'connected')
      .toList();

  Future<void> remove(String nodeId) async {
    _liveNodes.remove(nodeId);
    _health.remove(nodeId);
    await _db.nodes.deleteNode(nodeId);
    _bus.publish(NodeRemoved(nodeId));
  }

  Future<List<BridgeNode>> allNodes() async {
    final rows = await _db.nodes.allNodes();
    return rows.map((r) {
      final live = _liveNodes[r.id];
      return BridgeNode(
        id: r.id,
        name: live?.name ?? r.name,
        kind: live?.kind ?? NodeKind.values.firstWhere((k) => k.name == r.kind),
        detail: live?.detail ?? r.url ?? '',
        tabId: live?.tabId ?? r.tabId,
        url: live?.url ?? r.url,
        capabilities: live?.capabilities ?? const [],
        taskDomains: live?.taskDomains ?? const [],
        processId: live?.processId,
        windowId: live?.windowId,
        adapterId: live?.adapterId,
        adapterVersion: live?.adapterVersion,
        health: _health[r.id] ?? live?.health ?? 'unknown',
        permissionState: live?.permissionState ?? 'unknown',
      );
    }).toList();
  }

  Future<void> updateHealth(String nodeId, String health) async {
    _health[nodeId] = health;
    await _db.nodes.updateHealth(nodeId, health);
    _bus.publish(AdapterHealthEvent(nodeId, health));
  }
}
