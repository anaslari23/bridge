import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:brigade_bridge/daemon/artifact_store.dart';

void main() {
  late Directory root;
  late ArtifactStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('bridge-artifacts-test-');
    store = ArtifactStore(root);
  });

  tearDown(() => root.delete(recursive: true));

  test('writes output and verifiable metadata', () async {
    final artifact = await store.save('task-1', 'hello artifact');
    expect(await store.read('task-1'), 'hello artifact');
    expect(artifact.taskId, 'task-1');
    expect(artifact.sizeBytes, utf8.encode('hello artifact').length);
    expect(artifact.contentHash, hasLength(64));

    final metadata =
        jsonDecode(await File('${root.path}/task-1/meta.json').readAsString())
            as Map<String, dynamic>;
    expect(metadata['taskId'], 'task-1');
    expect(metadata['contentHash'], artifact.contentHash);
    expect(metadata['sizeBytes'], artifact.sizeBytes);
  });

  test('stores binary artifacts with detected MIME type', () async {
    final artifact = await store.saveBytes(
      'task-image',
      const [137, 80, 78, 71],
      fileName: 'screenshot.png',
    );
    expect(artifact.mimeType, 'image/png');
    expect(artifact.sizeBytes, 4);
    expect(await File(artifact.path).readAsBytes(), [137, 80, 78, 71]);
  });

  test('redacts credentials before storing text output', () async {
    await store.save('task-secret', 'api_key=do-not-store-this');

    final stored = await store.read('task-secret');
    expect(stored, 'api_key=[REDACTED]');
    expect(stored, isNot(contains('do-not-store-this')));
  });
}
