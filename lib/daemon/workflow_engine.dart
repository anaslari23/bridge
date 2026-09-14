import 'dart:async';
import 'package:uuid/uuid.dart';
import '../core/bridge_models.dart';
import 'event_bus.dart';
import 'permission_manager.dart';
import 'task_scheduler.dart';
import 'artifact_store.dart';
import 'node_registry.dart';

class WorkflowEngine {
  WorkflowEngine({
    required this.registry,
    required this.scheduler,
    required this.permissionManager,
    required this.artifactStore,
    required this.bus,
  });

  final NodeRegistry registry;
  final TaskScheduler scheduler;
  final PermissionManager permissionManager;
  final ArtifactStore artifactStore;
  final EventBus bus;

  bool _stopped = false;
  final _uuid = const Uuid();

  // Injected by adapter_manager after construction
  Future<String?> Function(String nodeId, String text)? sendToAdapter;

  void emergencyStop() {
    _stopped = true;
    scheduler.stop();
    bus.publish(LogEntry('Emergency stop activated', severity: 'emergency'));
  }

  void reset() {
    _stopped = false;
    scheduler.resume();
  }

  Future<void> run({
    required List<BridgeNode> nodes,
    required List<NodeEdge> edges,
    required String taskText,
    String? workflowId,
  }) async {
    if (_stopped) return;

    bus.publish(LogEntry('Workflow started'));

    // Build ordered node sequence from edges
    final ordered = _topologicalOrder(nodes, edges);
    String carryText = taskText;

    for (final node in ordered) {
      if (_stopped) break;

      final task = BridgeTask(
        id: _uuid.v4(),
        sourceNodeId: ordered.indexOf(node) > 0
            ? ordered[ordered.indexOf(node) - 1].id
            : 'user',
        targetNodeId: node.id,
        instruction: carryText,
      );

      // Permission check
      final allowed = await permissionManager.checkAndRequest(
          node.id, 'send_text', task);
      if (!allowed || _stopped) {
        bus.publish(LogEntry('Task denied or stopped for ${node.name}'));
        break;
      }

      // Dispatch
      scheduler.setHandler((t) async {
        final result = await sendToAdapter?.call(node.id, t.instruction);
        if (result != null) {
          await artifactStore.save(t.id, result);
        }
        return result;
      });

      final result = await scheduler.dispatch(task);
      carryText = result ?? carryText; // carry output forward
    }

    if (!_stopped) bus.publish(LogEntry('Workflow completed'));
  }

  List<BridgeNode> _topologicalOrder(
      List<BridgeNode> nodes, List<NodeEdge> edges) {
    // For the first milestone: edges define a simple chain.
    // Walk edges from any node with no incoming edge.
    final inDegree = {for (final n in nodes) n.id: 0};
    for (final e in edges) {
      inDegree[e.to] = (inDegree[e.to] ?? 0) + 1;
    }
    final queue = nodes.where((n) => inDegree[n.id] == 0).toList();
    final result = <BridgeNode>[];
    while (queue.isNotEmpty) {
      final n = queue.removeAt(0);
      result.add(n);
      for (final e in edges.where((e) => e.from == n.id)) {
        final next = nodes.firstWhere((x) => x.id == e.to, orElse: () => n);
        inDegree[e.to] = (inDegree[e.to] ?? 1) - 1;
        if (inDegree[e.to] == 0) queue.add(next);
      }
    }
    return result;
  }
}
