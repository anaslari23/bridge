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
  TextColumn get health => text().withDefault(const Constant('healthy'))();
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
  TextColumn get projectId => text().nullable()();
  TextColumn get parentTaskId => text().nullable()();
  IntColumn get handoffDepth => integer().withDefault(const Constant(0))();
  TextColumn get sourceNode => text()();
  TextColumn get targetNode => text()();
  TextColumn get instruction => text()();
  TextColumn get status => text().withDefault(const Constant('created'))();
  TextColumn get result => text().nullable()();
  TextColumn get error => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class ProjectRecords extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class ApprovalGrants extends Table {
  TextColumn get projectId => text()();
  TextColumn get nodeId => text()();
  TextColumn get capability => text()();
  IntColumn get grantedAt => integer()();

  @override
  Set<Column> get primaryKey => {projectId, nodeId, capability};
}

class AuditLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ts => integer()();
  TextColumn get nodeId => text()();
  TextColumn get capability => text()();
  TextColumn get decision => text()();
  TextColumn get taskId => text()();
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// ── DAOs ──────────────────────────────────────────────────────────────────────

@DriftAccessor(tables: [Nodes])
class NodesDao extends DatabaseAccessor<BridgeDatabase> with _$NodesDaoMixin {
  NodesDao(super.db);

  Future<void> upsertNode(NodesCompanion node) =>
      into(nodes).insertOnConflictUpdate(node);

  Future<List<Node>> allNodes() => select(nodes).get();

  Future<void> updateHealth(String id, String health) =>
      (update(nodes)..where((t) => t.id.equals(id)))
          .write(NodesCompanion(health: Value(health)));

  Future<void> deleteNode(String id) =>
      (delete(nodes)..where((t) => t.id.equals(id))).go();
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
class TasksDao extends DatabaseAccessor<BridgeDatabase> with _$TasksDaoMixin {
  TasksDao(super.db);

  Future<void> upsertTask(TasksCompanion task) =>
      into(tasks).insertOnConflictUpdate(task);

  Future<List<Task>> incompleteTasks() => (select(tasks)
        ..where((t) => t.status.isNotIn(['completed', 'cancelled', 'failed'])))
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

  Future<List<Task>> completedForWorkflow(String workflowId) => (select(tasks)
        ..where((t) =>
            t.workflowId.equals(workflowId) & t.status.equals('completed')))
      .get();

  Future<List<Task>> forWorkflow(String workflowId) =>
      (select(tasks)..where((t) => t.workflowId.equals(workflowId))).get();
}

@DriftAccessor(tables: [AuditLog])
class AuditDao extends DatabaseAccessor<BridgeDatabase> with _$AuditDaoMixin {
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

  Future<List<AuditLogData>> recent({int limit = 100}) => (select(auditLog)
        ..orderBy([(t) => OrderingTerm.desc(t.ts)])
        ..limit(limit))
      .get();
}

@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<BridgeDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Future<String?> valueFor(String key) async {
    final row = await (select(settings)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setValue(String key, String value) =>
      into(settings).insertOnConflictUpdate(SettingsCompanion.insert(
        key: key,
        value: value,
      ));
}

// ── Database ──────────────────────────────────────────────────────────────────

@DriftDatabase(
  tables: [
    Nodes,
    Workflows,
    Tasks,
    AuditLog,
    Settings,
    ProjectRecords,
    ApprovalGrants
  ],
  daos: [NodesDao, WorkflowsDao, TasksDao, AuditDao, SettingsDao],
)
class BridgeDatabase extends _$BridgeDatabase {
  BridgeDatabase(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(settings);
          if (from < 3) {
            await m.createTable(projectRecords);
            await m.createTable(approvalGrants);
            await m.addColumn(tasks, tasks.projectId);
            await m.addColumn(tasks, tasks.parentTaskId);
            await m.addColumn(tasks, tasks.handoffDepth);
          }
        },
      );

  static Future<BridgeDatabase> open() async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'BrigadeBridge', 'brigade.db');
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

  Future<void> deleteNode(String id) =>
      (attachedDatabase as BridgeDatabase).nodesDao.deleteNode(id);
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

  Future<List<Task>> completedForWorkflow(String workflowId) =>
      (attachedDatabase as BridgeDatabase)
          .tasksDao
          .completedForWorkflow(workflowId);

  Future<List<Task>> forWorkflow(String workflowId) =>
      (attachedDatabase as BridgeDatabase).tasksDao.forWorkflow(workflowId);
}

extension BridgeDbOps on BridgeDatabase {
  AuditDao get audit => auditDao;
}
