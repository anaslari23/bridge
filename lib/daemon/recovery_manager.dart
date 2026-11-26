import 'database.dart';
import 'event_bus.dart';
import 'workflow_engine.dart';

class RecoveryManager {
  RecoveryManager(this._db, this._bus);
  final BridgeDatabase _db;
  final EventBus _bus;

  Future<void> replayIncomplete(WorkflowEngine engine) async {
    final incomplete = await _db.tasks.incompleteTasks();
    if (incomplete.isEmpty) return;
    final taskIds = incomplete.map((task) => task.id).toList();
    _bus.publish(RecoveryRequired(taskIds));
    _bus.publish(LogEntry(
        'Recovered ${incomplete.length} incomplete task(s) from previous session'));
    // Mark them as failed — they will need to be re-run by the user
    for (final t in incomplete) {
      await _db.tasks.updateStatus(t.id, 'failed',
          error: 'Interrupted — app was closed during execution');
    }
  }
}
