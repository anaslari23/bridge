import 'package:drift/drift.dart';
import '../core/bridge_models.dart';
import 'database.dart';
import 'event_bus.dart';

class NodeRegistry {
  NodeRegistry(this._db, this._bus);
  final BridgeDatabase _db;
  final EventBus _bus;

  Future<void> register(BridgeNode node) async {
    await _db.nodes.upsertNode(NodesCompanion(
      id: Value(node.id),
      name: Value(node.name),
      kind: Value(node.kind.name),
      url: Value(node.url),
      tabId: Value(node.tabId),
      createdAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
    _bus.publish(NodeRegistered(node));
    _bus.publish(LogEntry('Node registered: ${node.name}'));
  }

  Future<List<BridgeNode>> allNodes() async {
    final rows = await _db.nodes.allNodes();
    return rows.map((r) => BridgeNode(
          id: r.id,
          name: r.name,
          kind: NodeKind.values.firstWhere((k) => k.name == r.kind),
          detail: r.url ?? '',
          tabId: r.tabId,
          url: r.url,
        )).toList();
  }

  Future<void> updateHealth(String nodeId, String health) async {
    await _db.nodes.updateHealth(nodeId, health);
    _bus.publish(AdapterHealthEvent(nodeId, health));
  }
}
