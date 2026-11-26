import 'dart:async';
import 'package:uuid/uuid.dart';
import '../core/bridge_models.dart';
import 'event_bus.dart';
import 'permission_manager.dart';
import 'task_scheduler.dart';
import 'artifact_store.dart';
import 'node_registry.dart';
import 'lead_router.dart';

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
  BridgeTask? _activeTask;
  final _activeWorkflowIds = <String>{};
  final _uuid = const Uuid();

  // Injected by adapter_manager after construction
  Future<String?> Function(String nodeId, String text)? sendToAdapter;

  /// Optional task-aware adapter hook for local integrations such as terminal.
  Future<String?> Function(BridgeTask task)? executeTask;

  /// Dispatches a complete task to a remote adapter, including structured
  /// context and attachment metadata when the adapter supports it.
  Future<String?> Function(BridgeTask task)? dispatchTask;

  /// Read-only context provider used for explicitly selected context nodes.
  Future<String?> Function(String nodeId)? readContext;

  /// Produces a read-only preview before a file write is approval-gated.
  Future<String?> Function(BridgeTask task)? previewTask;

  /// Cancels the currently executing adapter task when the workflow stops.
  Future<void> Function(BridgeTask task)? cancelTask;

  void emergencyStop() {
    _stopped = true;
    scheduler.stop();
    bus.publish(LogEntry('Emergency stop activated', severity: 'emergency'));
  }

  void reset() {
    _stopped = false;
    scheduler.resume();
  }

  void cancelActive() {
    scheduler.cancelActive();
    bus.publish(LogEntry('Active workflow cancellation requested'));
  }

  Future<void> run({
    required List<BridgeNode> nodes,
    required List<NodeEdge> edges,
    required String taskText,
    String projectId = 'project-default',
    String? targetNodeId,
    String? workflowId,
    bool resumeCompleted = false,
    List<BridgeAttachment> attachments = const [],
    List<String> contextNodeIds = const [],
  }) async {
    if (_stopped) return;

    if (workflowId != null) {
      if (!_activeWorkflowIds.add(workflowId)) {
        bus.publish(LogEntry('Duplicate workflow ignored: $workflowId',
            severity: 'warning'));
        return;
      }
      if (!resumeCompleted &&
          (await scheduler.tasksForWorkflow(workflowId)).isNotEmpty) {
        _activeWorkflowIds.remove(workflowId);
        bus.publish(LogEntry(
            'Workflow already exists; use retry to resume: $workflowId',
            severity: 'warning'));
        return;
      }
    }

    try {
      bus.publish(LogEntry('Workflow started'));

      // Build ordered node sequence from edges
      final ordered = targetNodeId == null
          ? _topologicalOrder(nodes, edges)
          : nodes.where((node) => node.id == targetNodeId).take(1).toList();
      if (targetNodeId != null && ordered.isEmpty) {
        bus.publish(LogEntry('Selected lead is no longer connected',
            severity: 'error'));
        return;
      }
      final effectiveWorkflowId =
          workflowId ?? 'workflow-${DateTime.now().microsecondsSinceEpoch}';
      final completed = <String, String?>{};
      if (resumeCompleted && workflowId != null) {
        for (final task in await scheduler.completedForWorkflow(workflowId)) {
          completed[task.targetNode] = task.result;
        }
      }
      var carryText = taskText;
      var paused = false;
      var halted = false;
      if (contextNodeIds.isNotEmpty && readContext != null) {
        final context = <String>[];
        for (final nodeId in contextNodeIds.take(5)) {
          final output = await readContext!.call(nodeId);
          if (output != null && output.trim().isNotEmpty) {
            context.add('[$nodeId]\n${output.trim()}');
          }
        }
        if (context.isNotEmpty) {
          final bounded = context.join('\n\n');
          carryText =
              '$taskText\n\n[Brigade Bridge selected context]\n$bounded';
          bus.publish(
              LogEntry('Loaded ${context.length} selected context node(s)'));
        } else {
          bus.publish(LogEntry(
            'Selected context was unavailable; dispatching without extra context',
            severity: 'warning',
          ));
        }
      }

      for (final node in ordered) {
        if (_stopped) break;
        if (completed.containsKey(node.id)) {
          carryText = completed[node.id] ?? carryText;
          bus.publish(
              LogEntry('Resuming workflow after completed node: ${node.name}'));
          continue;
        }
        if (node.health == 'degraded' || node.health == 'unavailable') {
          paused = true;
          bus.publish(WorkflowPaused(node.id, node.name, node.health));
          bus.publish(LogEntry(
              'Workflow paused: ${node.name} is ${node.health}',
              severity: 'warning'));
          break;
        }

        final task = BridgeTask(
          id: _uuid.v4(),
          sourceNodeId: ordered.indexOf(node) > 0
              ? ordered[ordered.indexOf(node) - 1].id
              : 'user',
          targetNodeId: node.id,
          instruction: carryText,
          projectId: projectId,
          workflowId: effectiveWorkflowId,
          attachments: attachments,
          contextNodeIds: contextNodeIds,
        );

        // Terminal work is a command execution, not text input. Keeping this
        // distinction here ensures the stricter approval tier is used even when
        // a terminal is reached through a multi-node workflow.
        final capability =
            _capabilityFor(node, task.instruction, task.attachments);
        final preview =
            capability == 'write_file' ? await previewTask?.call(task) : null;
        final allowed = await permissionManager.checkAndRequest(
          approvalId: task.id,
          nodeId: node.id,
          capability: capability,
          task: task,
          projectId: projectId,
          preview: preview,
        );
        if (!allowed || _stopped) {
          halted = true;
          bus.publish(LogEntry('Task denied or stopped for ${node.name}'));
          break;
        }

        // Dispatch
        scheduler.setHandler((t) async {
          String? result;
          if (executeTask != null) result = await executeTask!.call(t);
          if (result == null && dispatchTask != null) {
            result = await dispatchTask!.call(t);
          }
          if (result == null && sendToAdapter != null) {
            result = await sendToAdapter!.call(node.id, t.instruction);
          }
          if (result != null) {
            final artifact = await artifactStore.save(t.id, result);
            bus.publish(ArtifactCreated(
              taskId: artifact.taskId,
              path: artifact.path,
              sizeBytes: artifact.sizeBytes,
              contentHash: artifact.contentHash,
              mimeType: artifact.mimeType,
            ));
          }
          return result;
        });
        scheduler.setCancelHandler((taskId) async {
          final active = _activeTask;
          if (active?.id == taskId) await cancelTask?.call(active!);
        });

        _activeTask = task;
        try {
          final result = await scheduler.dispatch(task);
          carryText = result ?? carryText; // carry output forward
        } finally {
          if (_activeTask?.id == task.id) _activeTask = null;
        }
      }

      if (!_stopped && !paused && !halted) {
        bus.publish(LogEntry('Workflow completed'));
      }
    } finally {
      if (workflowId != null) _activeWorkflowIds.remove(workflowId);
    }
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

  String _capabilityFor(
      BridgeNode node, String instruction, List<BridgeAttachment> attachments) {
    if (node.kind == NodeKind.terminal) return 'run_command';
    if (node.kind == NodeKind.file) {
      return instruction.trimLeft().startsWith('write ')
          ? 'write_file'
          : 'read_file';
    }
    if (node.kind == NodeKind.browser && attachments.isNotEmpty) {
      return 'upload_file';
    }
    if (node.capabilities.contains('web_research') &&
        TaskDomainClassifier.classify(instruction).contains('web_research')) {
      return 'web_research';
    }
    return 'send_text';
  }
}
