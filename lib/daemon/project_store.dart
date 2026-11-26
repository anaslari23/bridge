import 'package:drift/drift.dart';
import '../core/bridge_models.dart';
import 'database.dart';

class ProjectStore {
  ProjectStore(this._db);
  final BridgeDatabase _db;

  static const defaultProjectId = 'project-default';
  static const _activeProjectKey = 'active_project_id';

  Future<void> initialize() async {
    if (await _db
        .select(_db.projectRecords)
        .get()
        .then((rows) => rows.isEmpty)) {
      await create(id: defaultProjectId, name: 'Default project');
    }
    final activeId = await _db.settingsDao.valueFor(_activeProjectKey);
    final project = activeId == null
        ? null
        : await (_db.select(_db.projectRecords)
              ..where((row) => row.id.equals(activeId)))
            .getSingleOrNull();
    if (project == null) {
      final first = (await list()).first;
      await setActive(first.id);
    }
  }

  Future<List<ProjectContext>> list() async =>
      (await _db.select(_db.projectRecords).get())
          .map((row) => ProjectContext(id: row.id, name: row.name))
          .toList();

  Future<void> create({required String id, required String name}) async {
    final cleanId = id.trim();
    final cleanName = name.trim();
    if (cleanId.isEmpty || cleanName.isEmpty) {
      throw ArgumentError('Project ID and name must be non-empty');
    }
    await _db.into(_db.projectRecords).insertOnConflictUpdate(
          ProjectRecordsCompanion.insert(
            id: cleanId,
            name: cleanName,
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  Future<void> rename(String id, String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty)
      throw ArgumentError('Project name must be non-empty');
    final changed = await (_db.update(_db.projectRecords)
          ..where((row) => row.id.equals(id)))
        .write(ProjectRecordsCompanion(name: Value(cleanName)));
    if (changed == 0) throw StateError('Unknown project: $id');
  }

  Future<void> setActive(String projectId) async {
    final exists = await (_db.select(_db.projectRecords)
          ..where((row) => row.id.equals(projectId)))
        .getSingleOrNull();
    if (exists == null) throw StateError('Unknown project: $projectId');
    await _db.settingsDao.setValue(_activeProjectKey, projectId);
  }

  Future<ProjectContext?> activeProject() async {
    final id = await _db.settingsDao.valueFor(_activeProjectKey);
    if (id == null) return null;
    final row = await (_db.select(_db.projectRecords)
          ..where((project) => project.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : ProjectContext(id: row.id, name: row.name);
  }

  Future<bool> contains(String projectId) async =>
      await (_db.select(_db.projectRecords)
            ..where((project) => project.id.equals(projectId)))
          .getSingleOrNull() !=
      null;
}
