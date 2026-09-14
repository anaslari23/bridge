import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';
import 'dart:convert';

class ArtifactStore {
  ArtifactStore(this._baseDir);
  final Directory _baseDir;

  Future<String> save(String taskId, String content) async {
    final dir = Directory(p.join(_baseDir.path, taskId));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, 'output.txt'));
    await file.writeAsString(content);
    final hash = sha256.convert(utf8.encode(content)).toString();
    final meta = File(p.join(dir.path, 'meta.json'));
    await meta.writeAsString(
        '{"taskId":"$taskId","contentHash":"$hash","ts":${DateTime.now().millisecondsSinceEpoch}}');
    return file.path;
  }

  Future<String?> read(String taskId) async {
    final file = File(p.join(_baseDir.path, taskId, 'output.txt'));
    if (await file.exists()) return file.readAsString();
    return null;
  }
}
