import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

// ── Tables ────────────────────────────────────────────────────────────────────

class Nodes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get kind => text()();
  TextColumn get url => text().nullable()();
  IntColumn get tabId => integer().nullable()();
  TextColumn get permissionTier =>
      text().withDefault(const Constant('read_only'))();
  TextColumn get health =>
      text().withDefault(const Constant('healthy'))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Workflows extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get graphJson => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get workflowId => text().nullable()();
  TextColumn get sourceNode => text()();
  TextColumn get targetNode => text()();
  TextColumn get instruction => text()();
  TextColumn get status =>
      text().withDefault(const Constant('created'))();
  TextColumn get result => text().nullable()();
  TextColumn get error => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class AuditLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ts => integer()();
  TextColumn get nodeId => text()();
  TextColumn get capability => text()();
  TextColumn get decision => text()();
  TextColumn get taskId => text()();
}

// ── DAOs ──────────────────────────────────────────────────────────────────────

@DriftAccessor(tables: [Nodes])
class NodesDao extends DatabaseAccessor<BridgeDatabase>
    with _$NodesDaoMixin {
  NodesDao(super.db);

  Future<void> upsertNode(NodesCompanion node) =>
      into(nodes).insertOnConflictUpdate(node);

  Future<List<Node>> allNodes() => select(nodes).get();

  Future<void> updateHealth(String id, String health) =>
      (update(nodes)..where((t) => t.id.equals(id)))
          .write(NodesCompanion(health: Value(health)));
}

@DriftAccessor(tables: [Workflows])
class WorkflowsDao extends DatabaseAccessor<BridgeDatabase>
    with _$WorkflowsDaoMixin {
  WorkflowsDao(super.db);

  Future<void> upsertWorkflow(WorkflowsCompanion wf) =>
      into(workflows).insertOnConflictUpdate(wf);

  Future<List<Workflow>> allWorkflows() => select(workflows).get();
}

@DriftAccessor(tables: [Tasks])
class TasksDao extends DatabaseAccessor<BridgeDatabase>
    with _$TasksDaoMixin {
  TasksDao(super.db);

  Future<void> upsertTask(TasksCompanion task) =>
      into(tasks).insertOnConflictUpdate(task);

  Future<List<Task>> incompleteTasks() =>
      (select(tasks)
            ..where((t) =>
                t.status.isNotIn(['completed', 'cancelled', 'failed'])))
          .get();

  Future<void> updateStatus(String id, String status,
      {String? result, String? error}) async {
    var companion = TasksCompanion(
      status: Value(status),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    );
    if (result != null) {
      companion = companion.copyWith(result: Value(result));
    }
    if (error != null) {
      companion = companion.copyWith(error: Value(error));
    }
    await (update(tasks)..where((t) => t.id.equals(id))).write(companion);
  }
}

@DriftAccessor(tables: [AuditLog])
class AuditDao extends DatabaseAccessor<BridgeDatabase>
    with _$AuditDaoMixin {
  AuditDao(super.db);

  Future<void> log({
    required String nodeId,
    required String capability,
    required String decision,
    required String taskId,
  }) =>
      into(auditLog).insert(AuditLogCompanion.insert(
        ts: DateTime.now().millisecondsSinceEpoch,
        nodeId: nodeId,
        capability: capability,
        decision: decision,
        taskId: taskId,
      ));

  Future<List<AuditLogData>> recent({int limit = 100}) =>
      (select(auditLog)
            ..orderBy([(t) => OrderingTerm.desc(t.ts)])
            ..limit(limit))
          .get();
}

// ── Database ──────────────────────────────────────────────────────────────────

@DriftDatabase(
  tables: [Nodes, Workflows, Tasks, AuditLog],
  daos: [NodesDao, WorkflowsDao, TasksDao, AuditDao],
)
class BridgeDatabase extends _$BridgeDatabase {
  BridgeDatabase(super.e);

  @override
  int get schemaVersion => 1;

  static Future<BridgeDatabase> open() async {
    final dir = await getApplicationSupportDirectory();
    final dbPath =
        p.join(dir.path, 'BrigadeBridge', 'brigade.db');
    await Directory(p.dirname(dbPath)).create(recursive: true);
    return BridgeDatabase(NativeDatabase(File(dbPath)));
  }
}

extension NodesTableOps on $NodesTable {
  Future<void> upsertNode(NodesCompanion node) =>
      (attachedDatabase as BridgeDatabase).nodesDao.upsertNode(node);

  Future<List<Node>> allNodes() =>
      (attachedDatabase as BridgeDatabase).nodesDao.allNodes();

  Future<void> updateHealth(String id, String health) =>
      (attachedDatabase as BridgeDatabase).nodesDao.updateHealth(id, health);
}

extension TasksTableOps on $TasksTable {
  Future<void> upsertTask(TasksCompanion task) =>
      (attachedDatabase as BridgeDatabase).tasksDao.upsertTask(task);

  Future<List<Task>> incompleteTasks() =>
      (attachedDatabase as BridgeDatabase).tasksDao.incompleteTasks();

  Future<void> updateStatus(String id, String status,
          {String? result, String? error}) =>
      (attachedDatabase as BridgeDatabase)
          .tasksDao
          .updateStatus(id, status, result: result, error: error);
}

extension BridgeDbOps on BridgeDatabase {
  AuditDao get audit => auditDao;
}
