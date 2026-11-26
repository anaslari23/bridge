import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:brigade_bridge/core/bridge_models.dart';
import 'package:brigade_bridge/daemon/database.dart';
import 'package:brigade_bridge/daemon/event_bus.dart';
import 'package:brigade_bridge/daemon/task_scheduler.dart';

void main() {
  test('status events retain task routing context and result', () async {
    final db = BridgeDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final bus = EventBus();
    addTearDown(bus.dispose);
    final events = <TaskStatusChanged>[];
    final subscription = bus.stream.listen((event) {
      if (event is TaskStatusChanged) events.add(event);
    });
    addTearDown(subscription.cancel);

    final scheduler = TaskScheduler(db, bus, maxAttempts: 1);
    scheduler.setHandler((_) async => 'answer');
    final task = BridgeTask(
      id: 'task-1',
      workflowId: 'workflow-1',
      sourceNodeId: 'codex',
      targetNodeId: 'claude',
      instruction: 'Summarize this',
    );

    await scheduler.dispatch(task);
    await Future<void>.delayed(Duration.zero);

    expect(events.map((event) => event.status), [
      TaskStatus.queued,
      TaskStatus.working,
      TaskStatus.completed,
    ]);
    expect(events.last.task?.sourceNodeId, 'codex');
    expect(events.last.task?.targetNodeId, 'claude');
    expect(events.last.task?.workflowId, 'workflow-1');
    expect(events.last.result, 'answer');
    expect(events.last.task?.result, 'answer');
  });

  test('redacts task results in persisted status and emitted events', () async {
    final db = BridgeDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final bus = EventBus();
    addTearDown(bus.dispose);
    TaskStatusChanged? completed;
    final subscription = bus.stream.listen((event) {
      if (event is TaskStatusChanged && event.status == TaskStatus.completed) {
        completed = event;
      }
    });
    addTearDown(subscription.cancel);

    final scheduler = TaskScheduler(db, bus, maxAttempts: 1);
    scheduler.setHandler((_) async => 'api_key=hidden-value');
    final task = BridgeTask(
      id: 'task-secret',
      workflowId: 'workflow-secret',
      sourceNodeId: 'source',
      targetNodeId: 'target',
      instruction: 'Return the result',
    );

    await scheduler.dispatch(task);
    final persisted = (await db.tasks.forWorkflow('workflow-secret')).single;

    expect(completed?.result, 'api_key=[REDACTED]');
    expect(persisted.result, 'api_key=[REDACTED]');
    expect(task.result, 'api_key=hidden-value');
  });
}
