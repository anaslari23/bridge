import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart';
import '../core/bridge_models.dart';
import '../core/node_adapter.dart';
import 'event_bus.dart';
import 'database.dart';
import 'secret_redactor.dart';

typedef TaskHandler = Future<String?> Function(BridgeTask task);

class TaskScheduler {
  TaskScheduler(this._db, this._bus,
      {this.maxAttempts = 3,
      this.retryDelay = const Duration(milliseconds: 100)});
  final BridgeDatabase _db;
  final EventBus _bus;
  final int maxAttempts;
  final Duration retryDelay;

  TaskHandler? _handler;
  Future<void> Function(String taskId)? _cancelHandler;
  final _activeTasks = <String, BridgeTask>{};
  final _children = <String, Set<String>>{};
  final _taskCancelHandlers = <String, Future<void> Function(String taskId)>{};
  final _cancelledTaskIds = <String>{};
  bool _stopped = false;

  void setHandler(TaskHandler handler) => _handler = handler;

  void setCancelHandler(Future<void> Function(String taskId) handler) =>
      _cancelHandler = handler;

  void stop() {
    _stopped = true;
    cancelActive();
  }

  void cancelActive() {
    final roots = _activeTasks.values
        .where((task) => task.parentTaskId == null)
        .map((task) => task.id)
        .toList();
    for (final taskId in roots.isEmpty ? _activeTasks.keys.toList() : roots) {
      cancelTask(taskId);
    }
  }

  void cancelTask(String taskId) {
    if (!_activeTasks.containsKey(taskId)) return;
    _cancelledTaskIds.add(taskId);
    for (final childId in _children[taskId]?.toList() ?? const <String>[]) {
      cancelTask(childId);
    }
    final cancel = _taskCancelHandlers[taskId] ?? _cancelHandler;
    if (cancel != null) unawaited(cancel(taskId).catchError((_) {}));
  }

  void resume() => _stopped = false;

  Future<String?> dispatch(
    BridgeTask task, {
    TaskHandler? handler,
    Future<void> Function(String taskId)? cancelHandler,
  }) async {
    _cancelledTaskIds.remove(task.id);
    if (_stopped) {
      await _setStatus(task.id, 'cancelled', task: task);
      return null;
    }

    await _db.tasks.upsertTask(TasksCompanion.insert(
      id: task.id,
      workflowId: task.workflowId == null
          ? const Value.absent()
          : Value(task.workflowId),
      projectId: Value(task.projectId),
      parentTaskId: Value(task.parentTaskId),
      handoffDepth: Value(task.handoffDepth),
      sourceNode: task.sourceNodeId,
      targetNode: task.targetNodeId,
      instruction: task.instruction,
      createdAt: task.createdAt.millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));

    await _setStatus(task.id, 'queued', task: task);
    await _setStatus(task.id, 'working', task: task);

    _activeTasks[task.id] = task;
    _taskCancelHandlers[task.id] =
        cancelHandler ?? _cancelHandler ?? (_) async {};
    if (task.parentTaskId != null) {
      _children.putIfAbsent(task.parentTaskId!, () => <String>{}).add(task.id);
    }
    try {
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        if (_stopped || _cancelledTaskIds.contains(task.id)) {
          await _setStatus(task.id, 'cancelled', task: task);
          return null;
        }
        try {
          final result = await (handler ?? _handler)?.call(task);
          if (_stopped || _cancelledTaskIds.contains(task.id)) {
            await _setStatus(task.id, 'cancelled', task: task);
            return null;
          }
          await _setStatus(task.id, 'completed', result: result, task: task);
          return result;
        } catch (error) {
          final retryable = _isRetryable(error);
          if (!retryable || attempt == maxAttempts) {
            await _setStatus(task.id, 'failed',
                error: error.toString(), task: task);
            return null;
          }
          _bus.publish(TaskRetrying(task.id, attempt, maxAttempts,
              SecretRedactor.redact(error.toString())));
          _bus.publish(
              LogEntry('Task ${task.id} retrying ($attempt/$maxAttempts)'));
          await Future<void>.delayed(retryDelay * attempt);
        }
      }
      return null;
    } finally {
      _cancelledTaskIds.remove(task.id);
      _activeTasks.remove(task.id);
      _taskCancelHandlers.remove(task.id);
      final parentId = task.parentTaskId;
      if (parentId != null) {
        _children[parentId]?.remove(task.id);
        if (_children[parentId]?.isEmpty ?? false) _children.remove(parentId);
      }
      _children.remove(task.id);
    }
  }

  Future<List<Task>> completedForWorkflow(String workflowId) =>
      _db.tasks.completedForWorkflow(workflowId);

  Future<List<Task>> tasksForWorkflow(String workflowId) =>
      _db.tasks.forWorkflow(workflowId);

  bool _isRetryable(Object error) =>
      (error is AdapterDispatchException && error.retryable) ||
      error is TimeoutException ||
      error is SocketException;

  Future<void> _setStatus(String id, String status,
      {String? result, String? error, BridgeTask? task}) async {
    final safeResult = result == null ? null : SecretRedactor.redact(result);
    final safeError = error == null ? null : SecretRedactor.redact(error);
    if (task != null) {
      task.status = TaskStatus.values.firstWhere(
        (value) => value.name == _dartStatus(status),
        orElse: () => TaskStatus.created,
      );
      if (result != null) task.result = result;
      if (error != null) task.error = error;
    }
    await _db.tasks
        .updateStatus(id, status, result: safeResult, error: safeError);
    _bus.publish(TaskStatusChanged(
      id,
      TaskStatus.values.firstWhere((s) => s.name == _dartStatus(status)),
      result: safeResult,
      error: safeError,
      task: task,
    ));
    _bus.publish(LogEntry('Task $id → $status'));
  }

  String _dartStatus(String s) {
    const map = {
      'created': 'created',
      'queued': 'queued',
      'working': 'working',
      'waiting_for_approval': 'waitingForApproval',
      'paused': 'paused',
      'completed': 'completed',
      'failed': 'failed',
      'cancelled': 'cancelled',
      'stopped': 'stopped',
    };
    return map[s] ?? 'created';
  }
}
