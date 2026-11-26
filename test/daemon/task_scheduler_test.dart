import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brigade_bridge/core/bridge_models.dart';
import 'package:brigade_bridge/core/node_adapter.dart';
import 'package:brigade_bridge/daemon/database.dart';
import 'package:brigade_bridge/daemon/event_bus.dart';
import 'package:brigade_bridge/daemon/task_scheduler.dart';

void main() {
  late BridgeDatabase db;
  late EventBus bus;

  setUp(() {
    db = BridgeDatabase(NativeDatabase.memory());
    bus = EventBus();
  });
  tearDown(() async {
    bus.dispose();
    await db.close();
  });

  test('retries transient adapter failures with the same task', () async {
    final scheduler = TaskScheduler(db, bus, retryDelay: Duration.zero);
    final retries = <TaskRetrying>[];
    bus.stream.listen((event) {
      if (event is TaskRetrying) retries.add(event);
    });
    var attempts = 0;
    scheduler.setHandler((task) async {
      attempts++;
      if (attempts < 3) {
        throw AdapterDispatchException('temporary disconnect', retryable: true);
      }
      return 'done';
    });
    final task = BridgeTask(
        id: 'retry-task',
        sourceNodeId: 'source',
        targetNodeId: 'target',
        instruction: 'go');

    expect(await scheduler.dispatch(task), 'done');
    expect(attempts, 3);
    expect(retries.map((retry) => retry.attempt), [1, 2]);
  });

  test('does not retry permanent adapter failures', () async {
    final scheduler = TaskScheduler(db, bus, retryDelay: Duration.zero);
    var attempts = 0;
    scheduler.setHandler((task) async {
      attempts++;
      throw AdapterDispatchException('permission denied');
    });
    final task = BridgeTask(
        id: 'permanent-task',
        sourceNodeId: 'source',
        targetNodeId: 'target',
        instruction: 'go');

    expect(await scheduler.dispatch(task), isNull);
    expect(attempts, 1);
    final row = (await db.select(db.tasks).get()).single;
    expect(row.status, 'failed');
  });

  test('persists project and handoff correlation on each task', () async {
    final scheduler = TaskScheduler(db, bus, retryDelay: Duration.zero);
    scheduler.setHandler((task) async => 'child result');
    final task = BridgeTask(
      id: 'child-task',
      sourceNodeId: 'lead',
      targetNodeId: 'helper',
      instruction: 'inspect this part',
      projectId: 'project-alpha',
      parentTaskId: 'parent-task',
      handoffDepth: 2,
    );

    await scheduler.dispatch(task);

    final row = await (db.select(db.tasks)
          ..where((record) => record.id.equals(task.id)))
        .getSingle();
    expect(row.projectId, 'project-alpha');
    expect(row.parentTaskId, 'parent-task');
    expect(row.handoffDepth, 2);
  });

  test('emergency stop cancels an active handler', () async {
    final scheduler = TaskScheduler(db, bus, retryDelay: Duration.zero);
    final handlerStarted = Completer<void>();
    final handlerFinished = Completer<String?>();
    String? cancelledTask;
    scheduler.setHandler((task) {
      if (!handlerStarted.isCompleted) handlerStarted.complete();
      return handlerFinished.future;
    });
    scheduler.setCancelHandler((taskId) async {
      cancelledTask = taskId;
      if (!handlerFinished.isCompleted) handlerFinished.complete(null);
    });
    final task = BridgeTask(
      id: 'active-task',
      sourceNodeId: 'source',
      targetNodeId: 'target',
      instruction: 'go',
    );

    final dispatch = scheduler.dispatch(task);
    await handlerStarted.future;
    scheduler.stop();

    expect(await dispatch, isNull);
    expect(cancelledTask, task.id);
    expect((await db.select(db.tasks).get()).single.status, 'cancelled');
  });

  test('cancelling a parent cancels its active delegated child', () async {
    final scheduler = TaskScheduler(db, bus, retryDelay: Duration.zero);
    final childStarted = Completer<void>();
    final childResult = Completer<String?>();
    final cancelled = <String>[];
    final child = BridgeTask(
      id: 'child-active',
      sourceNodeId: 'lead',
      targetNodeId: 'helper',
      instruction: 'do the subtask',
      parentTaskId: 'parent-active',
      handoffDepth: 1,
    );
    final parent = BridgeTask(
      id: 'parent-active',
      sourceNodeId: 'user',
      targetNodeId: 'lead',
      instruction: 'delegate this',
    );
    final dispatch = scheduler.dispatch(
      parent,
      handler: (_) => scheduler.dispatch(
        child,
        handler: (_) {
          if (!childStarted.isCompleted) childStarted.complete();
          return childResult.future;
        },
        cancelHandler: (id) async {
          cancelled.add(id);
          if (!childResult.isCompleted) childResult.complete(null);
        },
      ),
      cancelHandler: (id) async => cancelled.add(id),
    );

    await childStarted.future;
    scheduler.stop();

    expect(await dispatch, isNull);
    expect(cancelled, containsAll(['parent-active', 'child-active']));
    final rows = await db.select(db.tasks).get();
    expect(rows.every((row) => row.status == 'cancelled'), isTrue);
  });
}
