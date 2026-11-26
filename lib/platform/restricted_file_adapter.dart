import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import '../core/bridge_models.dart';
import '../core/node_adapter.dart';

/// File adapter confined to one approved directory.
///
/// Instructions use a small protocol: `list [relative-dir]`, `read <path>`,
/// or `write <path>\n<content>`. The workflow permission manager is expected
/// to approve `write_file` before [execute] is called for writes.
class RestrictedFileAdapter implements NodeAdapter {
  RestrictedFileAdapter({
    required Directory root,
    this.maxFileBytes = 1024 * 1024,
  }) : _root = root;

  Directory _root;
  final int maxFileBytes;

  @override
  String get id => 'restricted-files';

  String get rootPath => _root.path;

  Future<void> setRoot(String path) async {
    final directory = Directory(path);
    if (!directory.isAbsolute || !await directory.exists()) {
      throw StateError(
          'Selected file root must be an existing absolute directory');
    }
    _root = directory;
  }

  @override
  Future<List<BridgeNode>> discover() async {
    if (!await _root.exists()) return const [];
    return [
      BridgeNode(
        id: 'files-local',
        name: 'Files',
        kind: NodeKind.file,
        detail: _root.path,
        adapterId: id,
        adapterVersion: 'v1',
        capabilities: const ['read_file', 'write_file'],
        health: 'connected',
      )
    ];
  }

  @override
  Future<void> connect(BridgeNode node) async {
    if (!await _root.exists()) throw StateError('File root is unavailable');
  }

  @override
  Future<String> inspect(BridgeNode node) async =>
      'Restricted files\nRoot: ${_root.path}\nMax file size: $maxFileBytes bytes';

  @override
  Future<String> execute(BridgeTask task) async {
    final lines = task.instruction.split('\n');
    final header = lines.first.trim();
    final separator = header.indexOf(' ');
    final operation = separator == -1 ? header : header.substring(0, separator);
    final argument =
        separator == -1 ? '' : header.substring(separator + 1).trim();

    switch (operation) {
      case 'list':
        final directory =
            await _safeDirectory(argument.isEmpty ? '.' : argument);
        final entries = await directory.list(followLinks: false).toList();
        entries
            .sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
        return entries
            .map((entry) => p.relative(entry.path, from: _root.path))
            .join('\n');
      case 'read':
        final file = await _safeFile(argument);
        final length = await file.length();
        if (length > maxFileBytes)
          throw StateError('File exceeds the configured size limit');
        return file.readAsString();
      case 'write':
        if (lines.length == 1)
          throw ArgumentError('Write content cannot be empty');
        final file = await _safeFile(argument, allowMissing: true);
        final content = lines.skip(1).join('\n');
        final contentBytes = utf8.encode(content);
        if (contentBytes.length > maxFileBytes) {
          throw StateError('Content exceeds the configured size limit');
        }
        final existed = await file.exists();
        if (existed && await file.length() > maxFileBytes) {
          throw StateError('Existing file exceeds the configured size limit');
        }
        final previous = existed ? await file.readAsString() : '';
        final previousHash =
            existed ? sha256.convert(utf8.encode(previous)).toString() : null;
        final diff = _boundedDiff(
          _unifiedDiff(
              p.relative(file.path, from: _root.path), previous, content),
        );
        await file.parent.create(recursive: true);
        await file.writeAsString(content);
        final newHash = sha256.convert(contentBytes).toString();
        return 'Wrote ${p.relative(file.path, from: _root.path)}\n'
            'Change: ${existed ? 'modified' : 'created'}\n'
            'Previous SHA-256: ${previousHash ?? 'none'}\n'
            'New SHA-256: $newHash\n'
            'Bytes: ${contentBytes.length}\n'
            'Diff:\n$diff';
      case 'preview':
        if (lines.length == 1)
          throw ArgumentError('Preview content cannot be empty');
        final file = await _safeFile(argument, allowMissing: true);
        final previous = await file.exists() ? await file.readAsString() : '';
        return _boundedDiff(
            _unifiedDiff(argument, previous, lines.skip(1).join('\n')));
      default:
        throw StateError('Unsupported file operation: $operation');
    }
  }

  @override
  Future<String?> readOutput(BridgeTask task) async => null;

  @override
  Future<void> waitForCompletion(BridgeTask task) async {}

  @override
  Future<void> cancel(String taskId) async {}

  @override
  Future<void> disconnect(BridgeNode node) async {}

  Future<File> _safeFile(String relative, {bool allowMissing = false}) async {
    final path = _validatedRelative(relative);
    final file = File(p.join(_root.path, path));
    if (allowMissing) {
      await _ensureExistingAncestorInsideRoot(file.parent);
    } else {
      if (!await file.exists())
        throw StateError('File does not exist: $relative');
      await _ensureInsideRoot(await file.resolveSymbolicLinks());
    }
    return file;
  }

  Future<Directory> _safeDirectory(String relative) async {
    final path = _validatedRelative(relative);
    final directory = Directory(p.join(_root.path, path));
    if (!await directory.exists())
      throw StateError('Directory does not exist: $relative');
    await _ensureInsideRoot(await directory.resolveSymbolicLinks());
    return directory;
  }

  String _validatedRelative(String relative) {
    if (relative.isEmpty ||
        p.isAbsolute(relative) ||
        relative.startsWith('~')) {
      throw StateError('File paths must be relative to the approved root');
    }
    final normalized = p.normalize(relative);
    if (normalized == '..' || normalized.startsWith('..${p.separator}')) {
      throw StateError('File path escapes the approved root');
    }
    return normalized;
  }

  Future<void> _ensureInsideRoot(String path) async {
    final root = p.normalize(await _root.resolveSymbolicLinks());
    final candidate = p.normalize(path);
    if (candidate != root && !p.isWithin(root, candidate)) {
      throw StateError('Resolved path escapes the approved root');
    }
  }

  Future<void> _ensureExistingAncestorInsideRoot(Directory directory) async {
    var current = directory;
    while (!await current.exists()) {
      final parent = current.parent;
      if (parent.path == current.path) {
        throw StateError('Could not resolve the approved file root');
      }
      current = parent;
    }
    await _ensureInsideRoot(await current.resolveSymbolicLinks());
  }

  String _unifiedDiff(String relativePath, String before, String after) {
    final oldLines = before.isEmpty ? const <String>[] : before.split('\n');
    final newLines = after.split('\n');
    final buffer = StringBuffer()
      ..writeln('--- a/$relativePath')
      ..writeln('+++ b/$relativePath')
      ..writeln('@@ -1,${oldLines.length} +1,${newLines.length} @@');
    final cells = oldLines.length * newLines.length;
    if (cells > 4000000) {
      for (final line in oldLines) {
        buffer.writeln('-$line');
      }
      for (final line in newLines) {
        buffer.writeln('+$line');
      }
      return buffer.toString().trimRight();
    }

    final lcs = List.generate(
      oldLines.length + 1,
      (_) => List<int>.filled(newLines.length + 1, 0),
    );
    for (var i = oldLines.length - 1; i >= 0; i--) {
      for (var j = newLines.length - 1; j >= 0; j--) {
        lcs[i][j] = oldLines[i] == newLines[j]
            ? lcs[i + 1][j + 1] + 1
            : (lcs[i + 1][j] > lcs[i][j + 1] ? lcs[i + 1][j] : lcs[i][j + 1]);
      }
    }
    var i = 0;
    var j = 0;
    while (i < oldLines.length && j < newLines.length) {
      if (oldLines[i] == newLines[j]) {
        buffer.writeln(' ${oldLines[i]}');
        i++;
        j++;
      } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
        buffer.writeln('-${oldLines[i++]}');
      } else {
        buffer.writeln('+${newLines[j++]}');
      }
    }
    while (i < oldLines.length) {
      buffer.writeln('-${oldLines[i++]}');
    }
    while (j < newLines.length) {
      buffer.writeln('+${newLines[j++]}');
    }
    return buffer.toString().trimRight();
  }

  String _boundedDiff(String diff) {
    const maxDiffBytes = 64 * 1024;
    final bytes = utf8.encode(diff);
    if (bytes.length <= maxDiffBytes) return diff;
    return '${utf8.decode(bytes.take(maxDiffBytes).toList(), allowMalformed: true)}\n[diff truncated]';
  }
}
