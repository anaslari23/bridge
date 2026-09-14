import 'dart:async';
import '../core/bridge_models.dart';
import 'event_bus.dart';
import 'database.dart';

typedef TaskHandler = Future<String?> Function(BridgeTask task);

class TaskScheduler {
  TaskScheduler(this._db, this._bus);
  final BridgeDatabase _db;
  final EventBus _bus;

  TaskHandler? _handler;
  bool _stopped = false;

  void setHandler(TaskHandler handler) => _handler = handler;

  void stop() => _stopped = true;
  void resume() => _stopped = false;

  Future<String?> dispatch(BridgeTask task) async {
    if (_stopped) {
      await _setStatus(task.id, 'cancelled');
      return null;
    }

    await _db.tasks.upsertTask(TasksCompanion.insert(
      id: task.id,
      sourceNode: task.sourceNodeId,
      targetNode: task.targetNodeId,
      instruction: task.instruction,
      createdAt: task.createdAt.millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));

    await _setStatus(task.id, 'queued');
    await _setStatus(task.id, 'working');

    try {
      final result = await _handler?.call(task);
      await _setStatus(task.id, 'completed', result: result);
      return result;
    } catch (e) {
      await _setStatus(task.id, 'failed', error: e.toString());
      return null;
    }
  }

  Future<void> _setStatus(String id, String status,
      {String? result, String? error}) async {
    await _db.tasks.updateStatus(id, status, result: result, error: error);
    _bus.publish(TaskStatusChanged(
      id,
      TaskStatus.values.firstWhere((s) => s.name == _dartStatus(status)),
      result: result,
      error: error,
    ));
    _bus.publish(LogEntry('Task $id → $status'));
  }

  String _dartStatus(String s) {
    const map = {
      'created': 'created',
      'queued': 'queued',
      'working': 'working',
      'waiting_for_approval': 'waitingForApproval',
      'completed': 'completed',
      'failed': 'failed',
      'cancelled': 'cancelled',
      'stopped': 'stopped',
    };
    return map[s] ?? 'created';
  }
}
