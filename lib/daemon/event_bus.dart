import 'dart:async';
import '../core/bridge_models.dart';
import 'secret_redactor.dart';

// ── Event types ───────────────────────────────────────────────────────────────

sealed class DaemonEvent {}

class NodeRegistered extends DaemonEvent {
  NodeRegistered(this.node);
  final BridgeNode node;
}

class NodeRemoved extends DaemonEvent {
  NodeRemoved(this.nodeId);
  final String nodeId;
}

class TaskStatusChanged extends DaemonEvent {
  TaskStatusChanged(this.taskId, this.status,
      {this.result, this.error, this.task});
  final String taskId;
  final TaskStatus status;
  final String? result;
  final String? error;

  /// Task context allows clients to render source/target routing details.
  final BridgeTask? task;
}

class TaskRetrying extends DaemonEvent {
  TaskRetrying(this.taskId, this.attempt, this.maxAttempts, this.error);
  final String taskId;
  final int attempt;
  final int maxAttempts;
  final String error;
}

class WorkflowPaused extends DaemonEvent {
  WorkflowPaused(this.nodeId, this.nodeName, this.health);
  final String nodeId;
  final String nodeName;
  final String health;
}

class RecoveryRequired extends DaemonEvent {
  RecoveryRequired(this.taskIds);
  final List<String> taskIds;
}

class ArtifactCreated extends DaemonEvent {
  ArtifactCreated({
    required this.taskId,
    required this.path,
    required this.sizeBytes,
    required this.contentHash,
    required this.mimeType,
  });
  final String taskId;
  final String path;
  final int sizeBytes;
  final String contentHash;
  final String mimeType;
}

class ApprovalRequired extends DaemonEvent {
  ApprovalRequired(this.task, this.sourceName, this.targetName,
      {required this.approvalId,
      required this.projectId,
      this.preview,
      required this.capability});
  final BridgeTask task;
  final String approvalId;
  final String projectId;
  final String sourceName;
  final String targetName;
  final String? preview;
  final String capability;
}

class ProjectIndexLoaded extends DaemonEvent {
  ProjectIndexLoaded(this.projects, this.activeProjectId);
  final List<ProjectContext> projects;
  final String activeProjectId;
}

class AdapterHealthEvent extends DaemonEvent {
  AdapterHealthEvent(this.nodeId, this.health);
  final String nodeId;
  final String health; // healthy | degraded | unavailable | requires_update
}

class LogEntry extends DaemonEvent {
  LogEntry(String message, {this.severity = 'info'})
      : message = SecretRedactor.redact(message);
  final String message;
  final String severity; // info | warning | emergency
}

class WorkspaceLoaded extends DaemonEvent {
  WorkspaceLoaded(this.id, this.name, this.graph);
  final String id;
  final String name;
  final Map<String, dynamic> graph;
}

class WorkspaceSummary {
  const WorkspaceSummary(this.id, this.name, {this.pinned = false});
  final String id;
  final String name;
  final bool pinned;
}

class WorkspaceIndexLoaded extends DaemonEvent {
  WorkspaceIndexLoaded(this.workspaces);
  final List<WorkspaceSummary> workspaces;
}

class SecuritySettingsLoaded extends DaemonEvent {
  SecuritySettingsLoaded(this.allowedDomains);
  final List<String> allowedDomains;
}

class LocalAuthReady extends DaemonEvent {
  LocalAuthReady(this.token);
  final String token;
}

// ── Bus ───────────────────────────────────────────────────────────────────────

class EventBus {
  final _controller = StreamController<DaemonEvent>.broadcast();
  Stream<DaemonEvent> get stream => _controller.stream;

  void publish(DaemonEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  void dispose() => _controller.close();
}
