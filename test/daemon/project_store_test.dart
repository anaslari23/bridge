import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brigade_bridge/daemon/database.dart';
import 'package:brigade_bridge/daemon/project_store.dart';
import 'package:brigade_bridge/core/bridge_models.dart';

void main() {
  late BridgeDatabase db;
  late ProjectStore projects;

  setUp(() async {
    db = BridgeDatabase(NativeDatabase.memory());
    projects = ProjectStore(db);
    await projects.initialize();
  });

  tearDown(() => db.close());

  test('creates, lists, renames, and restores the active project', () async {
    await projects.create(id: 'project-a', name: 'Alpha');
    await projects.create(id: 'project-b', name: 'Beta');
    await projects.rename('project-a', 'Alpha 2');
    await projects.setActive('project-a');

    expect((await projects.list()).map((project) => project.name),
        contains('Alpha 2'));
    expect(await projects.activeProject(),
        const ProjectContext(id: 'project-a', name: 'Alpha 2'));

    final restored = ProjectStore(db);
    expect(await restored.activeProject(),
        const ProjectContext(id: 'project-a', name: 'Alpha 2'));
  });

  test('does not store filesystem paths in project metadata', () async {
    await projects.create(id: 'project-a', name: 'Alpha');

    final row = await (db.select(db.projectRecords)
          ..where((project) => project.id.equals('project-a')))
        .getSingle();
    expect(row.id, 'project-a');
    expect(row.name, 'Alpha');
  });

  test('recognizes only explicitly registered project IDs', () async {
    expect(await projects.contains(ProjectStore.defaultProjectId), isTrue);
    expect(await projects.contains('unknown-project'), isFalse);
  });
}
