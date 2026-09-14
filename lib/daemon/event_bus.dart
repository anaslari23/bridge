import 'dart:async';
import '../core/bridge_models.dart';

// ── Event types ───────────────────────────────────────────────────────────────

sealed class DaemonEvent {}

class NodeRegistered extends DaemonEvent {
  NodeRegistered(this.node);
  final BridgeNode node;
}

class TaskStatusChanged extends DaemonEvent {
  TaskStatusChanged(this.taskId, this.status, {this.result, this.error});
  final String taskId;
  final TaskStatus status;
  final String? result;
  final String? error;
}

class ApprovalRequired extends DaemonEvent {
  ApprovalRequired(this.task, this.sourceName, this.targetName);
  final BridgeTask task;
  final String sourceName;
  final String targetName;
}

class AdapterHealthEvent extends DaemonEvent {
  AdapterHealthEvent(this.nodeId, this.health);
  final String nodeId;
  final String health; // healthy | degraded | unavailable | requires_update
}

class LogEntry extends DaemonEvent {
  LogEntry(this.message, {this.severity = 'info'});
  final String message;
  final String severity; // info | warning | emergency
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
