import 'dart:convert';
import 'package:drift/drift.dart';
import 'database.dart';

/// Persists the spatial canvas as a versioned JSON graph. Keeping the graph
/// opaque to the database lets the UI evolve without a schema migration for
/// every new canvas property.
class WorkspaceStore {
  WorkspaceStore(this.db);
  final BridgeDatabase db;

  Future<void> save({
    required String id,
    required String name,
    required Map<String, dynamic> graph,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await load(id);
    final persistedGraph = jsonDecode(jsonEncode(graph)) as Map<String, dynamic>;
    final existingMetadata = existing?.graph['_meta'] is Map ? Map<String, dynamic>.from(existing!.graph['_meta'] as Map) : <String, dynamic>{};
    final incomingMetadata = persistedGraph['_meta'] is Map ? Map<String, dynamic>.from(persistedGraph['_meta'] as Map) : <String, dynamic>{};
    if (existingMetadata.isNotEmpty || incomingMetadata.isNotEmpty) {
      persistedGraph['_meta'] = {...existingMetadata, ...incomingMetadata};
    }
    final document = <String, dynamic>{
      'version': 1,
      'savedAt': now,
      'graph': persistedGraph,
    };
    await db.workflowsDao.upsertWorkflow(WorkflowsCompanion(
      id: Value(id),
      name: Value(name),
      graphJson: Value(jsonEncode(document)),
      createdAt: Value(now),
    ));
  }

  Future<List<SavedWorkspace>> list() async {
    final rows = await db.workflowsDao.allWorkflows();
    return rows
        .map((row) => SavedWorkspace(
              id: row.id,
              name: row.name,
              graph: _decode(row.graphJson),
              pinned: _decode(row.graphJson)['_meta'] is Map && _decode(row.graphJson)['_meta']['pinned'] == true,
              createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
            ))
        .toList();
  }

  Future<SavedWorkspace?> load(String id) async {
    final matches = (await list()).where((workspace) => workspace.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  Future<void> markOpened(String id) async {
    final workspace = await load(id);
    if (workspace == null) return;
    final graph = jsonDecode(jsonEncode(workspace.graph)) as Map<String, dynamic>;
    final metadata = graph['_meta'] is Map ? Map<String, dynamic>.from(graph['_meta'] as Map) : <String, dynamic>{};
    metadata['lastOpenedAt'] = DateTime.now().millisecondsSinceEpoch;
    graph['_meta'] = metadata;
    await save(id: workspace.id, name: workspace.name, graph: graph);
  }

  Future<void> delete(String id) =>
      (db.delete(db.workflows)..where((table) => table.id.equals(id))).go();

  Future<void> rename(String id, String name) =>
      (db.update(db.workflows)..where((table) => table.id.equals(id)))
          .write(WorkflowsCompanion(name: Value(name)));

  Future<void> duplicate(String sourceId, String newId, String newName) async {
    final source = await load(sourceId);
    if (source == null) return;
    await save(id: newId, name: newName, graph: jsonDecode(jsonEncode(source.graph)) as Map<String, dynamic>);
  }

  Future<void> setPinned(String id, bool pinned) async {
    final source = await load(id);
    if (source == null) return;
    final graph = jsonDecode(jsonEncode(source.graph)) as Map<String, dynamic>;
    final metadata = graph['_meta'] is Map ? Map<String, dynamic>.from(graph['_meta'] as Map) : <String, dynamic>{};
    metadata['pinned'] = pinned;
    graph['_meta'] = metadata;
    await save(id: source.id, name: source.name, graph: graph);
  }

  Map<String, dynamic> _decode(String raw) {
    final value = jsonDecode(raw);
    if (value is Map && value['graph'] is Map) {
      return Map<String, dynamic>.from(value['graph'] as Map);
    }
    // Preserve compatibility with an early, unversioned graph format.
    return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  }
}

class SavedWorkspace {
  const SavedWorkspace({required this.id, required this.name, required this.graph, required this.createdAt, this.pinned = false});
  final String id;
  final String name;
  final Map<String, dynamic> graph;
  final DateTime createdAt;
  final bool pinned;
}
