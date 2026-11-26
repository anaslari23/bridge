import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'secret_redactor.dart';

class StoredArtifact {
  const StoredArtifact({
    required this.taskId,
    required this.path,
    required this.sizeBytes,
    required this.contentHash,
    required this.mimeType,
  });

  final String taskId;
  final String path;
  final int sizeBytes;
  final String contentHash;
  final String mimeType;
}

class ArtifactStore {
  ArtifactStore(this._baseDir);
  final Directory _baseDir;

  Future<StoredArtifact> save(String taskId, String content) async {
    final safeContent = SecretRedactor.redact(content);
    return saveBytes(
      taskId,
      utf8.encode(safeContent),
      fileName: 'output.txt',
      mimeType: 'text/plain',
    );
  }

  Future<StoredArtifact> saveBytes(
    String taskId,
    List<int> bytes, {
    required String fileName,
    String? mimeType,
  }) async {
    final safeName = p.basename(fileName);
    if (safeName.isEmpty || safeName == '.' || safeName == '..') {
      throw ArgumentError('Artifact filename is invalid');
    }
    final dir = Directory(p.join(_baseDir.path, taskId));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, safeName));
    await file.writeAsBytes(bytes, flush: true);
    final hash = sha256.convert(bytes).toString();
    final resolvedMime = mimeType ?? _mimeTypeFor(safeName);
    final meta = File(p.join(dir.path, 'meta.json'));
    await meta.writeAsString(jsonEncode({
      'taskId': taskId,
      'contentHash': hash,
      'sizeBytes': bytes.length,
      'fileName': safeName,
      'mimeType': resolvedMime,
      'ts': DateTime.now().millisecondsSinceEpoch,
    }));
    return StoredArtifact(
      taskId: taskId,
      path: file.path,
      sizeBytes: bytes.length,
      contentHash: hash,
      mimeType: resolvedMime,
    );
  }

  Future<String?> read(String taskId) async {
    final file = File(p.join(_baseDir.path, taskId, 'output.txt'));
    if (await file.exists()) return file.readAsString();
    return null;
  }

  String _mimeTypeFor(String fileName) {
    switch (p.extension(fileName).toLowerCase()) {
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.json':
        return 'application/json';
      case '.diff':
      case '.patch':
        return 'text/x-diff';
      default:
        return 'application/octet-stream';
    }
  }
}
