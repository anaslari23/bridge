import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:brigade_bridge/daemon/database.dart';
import 'package:brigade_bridge/daemon/workspace_store.dart';

void main() {
  test('saves and restores a versioned workspace graph', () async {
    final db = BridgeDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = WorkspaceStore(db);
    await store.save(
      id: 'workspace-1',
      name: 'Build flow',
      graph: {
        'nodes': [
          {'id': 'codex', 'x': 120, 'y': 80}
        ],
        'edges': [
          {'from': 'codex', 'to': 'claude'}
        ],
        'zoom': 0.8,
        'taskHistory': ['Started workflow', 'Workflow completed'],
        'lastWorkflow': {
          'type': 'RUN_WORKFLOW',
          'taskText': 'Retry this flow',
          'sourceNodeId': 'codex',
          'targetNodeId': 'claude',
        },
      },
    );

    final restored = await store.load('workspace-1');
    expect(restored?.name, 'Build flow');
    expect(restored?.graph['zoom'], 0.8);
    expect((restored?.graph['nodes'] as List).first['id'], 'codex');
    expect(restored?.graph['taskHistory'],
        ['Started workflow', 'Workflow completed']);
    expect(
      (restored?.graph['lastWorkflow'] as Map)['taskText'],
      'Retry this flow',
    );
  });

  test('duplicates a workspace and persists pin state', () async {
    final db = BridgeDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = WorkspaceStore(db);
    await store.save(id: 'source', name: 'Source', graph: {
      'nodes': [
        {'id': 'a'}
      ]
    });

    await store.duplicate('source', 'copy', 'Source copy');
    await store.setPinned('copy', true);

    final copied = await store.load('copy');
    expect(copied?.name, 'Source copy');
    expect(copied?.pinned, isTrue);
    expect((copied?.graph['nodes'] as List).single['id'], 'a');

    await store.markOpened('copy');
    final reopened = await store.load('copy');
    expect(reopened?.graph['_meta'], containsPair('lastOpenedAt', isA<int>()));
    expect(reopened?.pinned, isTrue);
  });
}
