import 'dart:async';
import 'package:drift/drift.dart';
import '../core/bridge_models.dart';
import 'database.dart';
import 'event_bus.dart';
import 'security_policy.dart';

const _tierRank = {
  'read_only': 0,
  'input': 1,
  'file': 2,
  'system': 3,
};

const _capabilityTier = {
  'read_text': 'read_only',
  'read_screen': 'read_only',
  'web_research': 'read_only',
  'send_text': 'input',
  'click': 'input',
  'upload_file': 'file',
  'download_file': 'file',
  'read_file': 'read_only',
  'write_file': 'file',
  'run_command': 'system',
  'open_link': 'system',
};

class PermissionManager {
  PermissionManager(this._db, this._bus, {SecurityPolicy? policy})
      : policy = policy ?? SecurityPolicy();
  final BridgeDatabase _db;
  final EventBus _bus;
  final SecurityPolicy policy;

  final _pending = <String, Completer<bool>>{};
  final _pendingScopes =
      <String, ({String projectId, String nodeId, String capability})>{};
  final _pendingTaskIds = <String, String>{};

  Future<bool> checkAndRequest({
    required String approvalId,
    required String nodeId,
    required String capability,
    required BridgeTask task,
    required String projectId,
    String? preview,
  }) async {
    if (capability == 'open_link' && !policy.allowsOpenLink(task.instruction)) {
      await _db.audit.log(
          nodeId: nodeId,
          capability: capability,
          decision: 'blocked_domain',
          taskId: task.id);
      _bus.publish(LogEntry(
        'Blocked open_link: add an approved HTTPS domain in settings',
        severity: 'warning',
      ));
      return false;
    }
    final rows =
        await (_db.select(_db.nodes)..where((t) => t.id.equals(nodeId))).get();
    if (rows.isEmpty) return false;

    final requiredTier = _capabilityTier[capability] ?? 'system';
    if ((_tierRank[requiredTier] ?? 3) == 0) {
      await _db.audit.log(
          nodeId: nodeId,
          capability: capability,
          decision: 'auto',
          taskId: task.id);
      return true;
    }

    final grant = await (_db.select(_db.approvalGrants)
          ..where((row) =>
              row.projectId.equals(projectId) &
              row.nodeId.equals(nodeId) &
              row.capability.equals(capability)))
        .getSingleOrNull();
    if (grant != null) {
      await _db.audit.log(
          nodeId: nodeId,
          capability: capability,
          decision: 'project_grant',
          taskId: task.id);
      return true;
    }

    if (_pending.containsKey(approvalId)) {
      throw StateError('Approval ID is already pending: $approvalId');
    }
    await _db.audit.log(
        nodeId: nodeId,
        capability: capability,
        decision: 'pending',
        taskId: task.id);

    final completer = Completer<bool>();
    _pending[approvalId] = completer;
    _pendingScopes[approvalId] = (
      projectId: projectId,
      nodeId: nodeId,
      capability: capability,
    );
    _pendingTaskIds[approvalId] = task.id;
    task.status = TaskStatus.waitingForApproval;
    _bus.publish(TaskStatusChanged(
      task.id,
      TaskStatus.waitingForApproval,
      task: task,
    ));
    _bus.publish(ApprovalRequired(
      task,
      rows.first.name,
      task.targetNodeId,
      approvalId: approvalId,
      projectId: projectId,
      preview: preview,
      capability: capability,
    ));

    return completer.future;
  }

  void setAllowedDomains(Iterable<String> domains) {
    policy.setAllowedDomains(domains);
    _bus.publish(SecuritySettingsLoaded(policy.allowedDomains));
  }

  Future<bool> checkAction(String nodeId, String action, BridgeTask task) {
    const capabilities = {
      'inspect_window': 'read_screen',
      'focus_window': 'read_screen',
      'set_focused_text': 'send_text',
      'press_focused_control': 'click',
      'capture_window': 'read_screen',
    };
    final capability = capabilities[action] ?? action;
    return checkAndRequest(
      approvalId: task.id,
      nodeId: nodeId,
      capability: capability,
      task: task,
      projectId: task.projectId,
    );
  }

  void approve(String approvalId) => _resolve(approvalId, true);

  void deny(String approvalId) => _resolve(approvalId, false);

  Future<void> allowForProject({
    required String approvalId,
    required String nodeId,
    required String capability,
    required String projectId,
  }) async {
    final pendingScope = _pendingScopes[approvalId];
    if (pendingScope == null ||
        pendingScope.projectId != projectId ||
        pendingScope.nodeId != nodeId ||
        pendingScope.capability != capability) {
      return;
    }
    await _db.into(_db.approvalGrants).insertOnConflictUpdate(
          ApprovalGrantsCompanion.insert(
            projectId: projectId,
            nodeId: nodeId,
            capability: capability,
            grantedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
    final taskId = _pendingTaskIds[approvalId];
    if (taskId != null) {
      await _db.audit.log(
          nodeId: nodeId,
          capability: capability,
          decision: 'always_allow_for_project',
          taskId: taskId);
    }
    approve(approvalId);
  }

  void _resolve(String approvalId, bool allowed) {
    _pendingScopes.remove(approvalId);
    _pendingTaskIds.remove(approvalId);
    final completer = _pending.remove(approvalId);
    if (completer != null && !completer.isCompleted)
      completer.complete(allowed);
  }

  void denyAll(Iterable<String> approvalIds) {
    for (final id in approvalIds) {
      deny(id);
    }
  }

  /// Resolves every outstanding approval as denied during workflow
  /// cancellation or emergency shutdown.
  void cancelAll() {
    for (final approvalId in _pending.keys.toList()) {
      deny(approvalId);
    }
  }
}
