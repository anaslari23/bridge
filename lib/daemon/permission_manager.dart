import 'dart:async';
import '../core/bridge_models.dart';
import 'database.dart';
import 'event_bus.dart';

const _tierRank = {
  'read_only': 0,
  'input': 1,
  'file': 2,
  'system': 3,
};

const _capabilityTier = {
  'read_text': 'read_only',
  'read_screen': 'read_only',
  'send_text': 'input',
  'click': 'input',
  'upload_file': 'file',
  'download_file': 'file',
  'run_command': 'system',
  'open_link': 'system',
};

class PermissionManager {
  PermissionManager(this._db, this._bus);
  final BridgeDatabase _db;
  final EventBus _bus;

  final _pending = <String, Completer<bool>>{};

  Future<bool> checkAndRequest(
      String nodeId, String capability, BridgeTask task) async {
    final rows = await (_db.select(_db.nodes)
          ..where((t) => t.id.equals(nodeId)))
        .get();
    if (rows.isEmpty) return false;

    final nodeTier = rows.first.permissionTier;
    final requiredTier = _capabilityTier[capability] ?? 'system';
    final nodeRank = _tierRank[nodeTier] ?? 0;
    final requiredRank = _tierRank[requiredTier] ?? 3;

    if (nodeRank >= requiredRank) {
      await _db.audit.log(
          nodeId: nodeId,
          capability: capability,
          decision: 'auto',
          taskId: task.id);
      return true;
    }

    await _db.audit.log(
        nodeId: nodeId,
        capability: capability,
        decision: 'pending',
        taskId: task.id);

    final completer = Completer<bool>();
    _pending[task.id] = completer;

    _bus.publish(ApprovalRequired(
        task, rows.first.name, task.targetNodeId));

    return completer.future;
  }

  void approve(String taskId) {
    final c = _pending.remove(taskId);
    if (c != null && !c.isCompleted) c.complete(true);
  }

  void deny(String taskId) {
    final c = _pending.remove(taskId);
    if (c != null && !c.isCompleted) c.complete(false);
  }

  void denyAll(List<String> taskIds) {
    for (final id in taskIds) {
      deny(id);
    }
  }
}
