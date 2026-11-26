import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:brigade_bridge/core/bridge_models.dart';
import 'package:brigade_bridge/platform/restricted_file_adapter.dart';

void main() {
  late Directory root;
  late RestrictedFileAdapter adapter;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('bridge-files-test-');
    adapter = RestrictedFileAdapter(root: root);
  });

  tearDown(() => root.delete(recursive: true));

  test('lists, reads, and writes files within the approved root', () async {
    final write = BridgeTask(
      id: 'write', sourceNodeId: 'user', targetNodeId: 'files-local',
      instruction: 'write notes/result.txt\nbridge output');
    final writeResult = await adapter.execute(write);
    expect(writeResult, contains('Wrote notes/result.txt'));
    expect(writeResult, contains('Change: created'));
    expect(writeResult, contains('Previous SHA-256: none'));
    expect(writeResult, contains('New SHA-256:'));
    expect(writeResult, contains('--- a/notes/result.txt'));
    expect(writeResult, contains('+++ b/notes/result.txt'));
    expect(await File(p.join(root.path, 'notes/result.txt')).readAsString(), 'bridge output');

    final modifyResult = await adapter.execute(BridgeTask(
      id: 'modify', sourceNodeId: 'user', targetNodeId: 'files-local',
      instruction: 'write notes/result.txt\nupdated output'));
    expect(modifyResult, contains('Change: modified'));
    expect(modifyResult, contains('Previous SHA-256:'));
    expect(modifyResult, contains('-bridge output'));
    expect(modifyResult, contains('+updated output'));

    final preview = await adapter.execute(BridgeTask(
      id: 'preview', sourceNodeId: 'user', targetNodeId: 'files-local',
      instruction: 'preview notes/result.txt\npreview only'));
    expect(preview, contains('-updated output'));
    expect(preview, contains('+preview only'));
    expect(await File(p.join(root.path, 'notes/result.txt')).readAsString(), 'updated output');

    final read = BridgeTask(
      id: 'read', sourceNodeId: 'user', targetNodeId: 'files-local',
      instruction: 'read notes/result.txt');
    expect(await adapter.execute(read), 'updated output');

    final list = BridgeTask(
      id: 'list', sourceNodeId: 'user', targetNodeId: 'files-local',
      instruction: 'list notes');
    expect(await adapter.execute(list), 'notes/result.txt');
  });

  test('rejects absolute and traversal paths', () async {
    BridgeTask task(String instruction) => BridgeTask(
        id: instruction, sourceNodeId: 'user', targetNodeId: 'files-local', instruction: instruction);
    expect(() => adapter.execute(task('read ../secret.txt')), throwsStateError);
    expect(() => adapter.execute(task('read /tmp/secret.txt')), throwsStateError);
    expect(() => adapter.execute(task('write ../secret.txt\nnope')), throwsStateError);
  });
}
