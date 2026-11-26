import 'package:uuid/uuid.dart';
import '../core/bridge_models.dart';
import '../core/node_adapter.dart';
import 'node_registry.dart';
import 'permission_manager.dart';
import 'task_scheduler.dart';

typedef DelegatedTaskRunner = Future<String?> Function(BridgeTask task);

class DelegationManager {
  DelegationManager({
    required this.registry,
    required this.scheduler,
    required this.permissions,
    this.maxDepth = 8,
  });

  final NodeRegistry registry;
  final TaskScheduler scheduler;
  final PermissionManager permissions;
  final int maxDepth;
  final Uuid _uuid = const Uuid();

  Future<String?> request({
    required BridgeTask parent,
    required String targetNodeId,
    required String instruction,
    required DelegatedTaskRunner runChild,
    Future<void> Function(String taskId)? cancelChild,
  }) async {
    final cleanInstruction = instruction.trim();
    if (cleanInstruction.isEmpty) {
      throw AdapterDispatchException('Delegated instruction is empty');
    }
    if (cleanInstruction.length > 2 * 1024 * 1024) {
      throw AdapterDispatchException('Delegated instruction is too large');
    }
    if (targetNodeId == parent.targetNodeId) {
      throw AdapterDispatchException('An app cannot delegate to itself');
    }
    if (parent.handoffDepth >= maxDepth) {
      throw AdapterDispatchException('Maximum delegation depth reached');
    }
    final connected = await registry.connectedNodes();
    final candidates = connected.where((node) => node.id == targetNodeId);
    final target = candidates.isEmpty ? null : candidates.first;
    if (target == null) {
      throw AdapterDispatchException('Delegated app is not connected');
    }
    if (!target.capabilities.contains('receive_task')) {
      throw AdapterDispatchException(
          'Delegated app does not support receiving tasks');
    }

    final child = BridgeTask(
      id: _uuid.v4(),
      workflowId: parent.workflowId,
      projectId: parent.projectId,
      parentTaskId: parent.id,
      handoffDepth: parent.handoffDepth + 1,
      sourceNodeId: parent.targetNodeId,
      targetNodeId: target.id,
      instruction: cleanInstruction,
    );
    final allowed = await permissions.checkAndRequest(
      approvalId: child.id,
      nodeId: target.id,
      capability: 'send_text',
      task: child,
      projectId: parent.projectId,
      preview: cleanInstruction,
    );
    if (!allowed) throw AdapterDispatchException('Delegated task was denied');

    final result = await scheduler.dispatch(
      child,
      handler: runChild,
      cancelHandler: cancelChild,
    );
    if (child.status != TaskStatus.completed || result == null) {
      throw AdapterDispatchException('Delegated app did not return a result');
    }
    return result;
  }
}
