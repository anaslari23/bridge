import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../core/bridge_models.dart';
import '../core/node_adapter.dart';

/// Local terminal adapter with a deliberately narrow execution boundary.
/// Callers must obtain `run_command` approval before invoking [execute].
class RestrictedTerminalAdapter implements NodeAdapter {
  RestrictedTerminalAdapter({
    required Directory workingDirectory,
    List<String> allowedCommands = const ['pwd', 'ls', 'cat', 'rg', 'find'],
    this.timeout = const Duration(minutes: 2),
    this.maxOutputBytes = 1024 * 1024,
  })  : _workingDirectory = workingDirectory,
        _allowedCommands = allowedCommands.toSet();

  Directory _workingDirectory;
  final Set<String> _allowedCommands;
  final Duration timeout;
  final int maxOutputBytes;
  final _processes = <String, Process>{};

  @override
  String get id => 'restricted-terminal';

  String get workingDirectoryPath => _workingDirectory.path;

  Future<void> setWorkingDirectory(String path) async {
    final directory = Directory(path);
    if (!await directory.exists()) {
      throw StateError('Selected terminal directory does not exist');
    }
    if (!directory.isAbsolute) {
      throw StateError('Terminal directory must be absolute');
    }
    _workingDirectory = directory;
  }

  @override
  Future<List<BridgeNode>> discover() async {
    if (!await _workingDirectory.exists()) return const [];
    return [
      BridgeNode(
        id: 'terminal-local',
        name: 'Terminal',
        kind: NodeKind.terminal,
        detail: _workingDirectory.path,
        adapterId: id,
        adapterVersion: 'v1',
        capabilities: const ['read_text', 'run_command'],
        health: 'connected',
      )
    ];
  }

  @override
  Future<void> connect(BridgeNode node) async {
    if (!await _workingDirectory.exists()) {
      throw StateError('Approved terminal directory does not exist');
    }
  }

  @override
  Future<String> inspect(BridgeNode node) async =>
      'Restricted terminal\nDirectory: ${_workingDirectory.path}\n'
      'Allowed commands: ${_allowedCommands.toList()..sort()}';

  @override
  Future<String> execute(BridgeTask task) async {
    final commandLine = task.instruction.trim();
    if (commandLine.isEmpty) throw ArgumentError('Command cannot be empty');
    if (RegExp(r'[;&|><`\$()]').hasMatch(commandLine) ||
        commandLine.contains('\n')) {
      throw StateError(
          'Shell operators and multiline commands are not allowed');
    }
    final parts = _tokenize(commandLine);
    final executable = parts.first;
    if (executable.contains(Platform.pathSeparator) || executable == '~') {
      throw StateError(
          'Executable paths are not allowed; use an allowlisted command name');
    }
    final commandName = executable;
    if (!_allowedCommands.contains(commandName)) {
      throw StateError('Command is not allowlisted: $commandName');
    }
    for (final argument in parts.skip(1)) {
      if (_isEscapingPath(argument)) {
        throw StateError(
            'Path argument escapes the approved terminal directory');
      }
    }
    if (!await _workingDirectory.exists()) {
      throw StateError('Approved terminal directory is unavailable');
    }

    final process = await Process.start(
      executable,
      parts.skip(1).toList(),
      workingDirectory: _workingDirectory.path,
      runInShell: false,
    );
    _processes[task.id] = process;
    try {
      final stdoutFuture = process.stdout.transform(utf8.decoder).join();
      final stderrFuture = process.stderr.transform(utf8.decoder).join();
      final exitCode = await process.exitCode.timeout(timeout, onTimeout: () {
        process.kill(ProcessSignal.sigterm);
        throw TimeoutException('Terminal command timed out', timeout);
      });
      final output = await stdoutFuture;
      final error = await stderrFuture;
      final combined = [output, if (error.isNotEmpty) 'stderr: $error']
          .where((part) => part.isNotEmpty)
          .join();
      final bytes = utf8.encode(combined);
      final bounded = bytes.length > maxOutputBytes
          ? '${utf8.decode(bytes.take(maxOutputBytes).toList(), allowMalformed: true)}\n[output truncated]'
          : combined;
      if (exitCode != 0)
        throw ProcessException(
            executable, parts.skip(1).toList(), bounded, exitCode);
      return bounded;
    } finally {
      _processes.remove(task.id);
    }
  }

  @override
  Future<String?> readOutput(BridgeTask task) async => null;

  @override
  Future<void> waitForCompletion(BridgeTask task) async {}

  @override
  Future<void> cancel(String taskId) async {
    _processes.remove(taskId)?.kill(ProcessSignal.sigterm);
  }

  @override
  Future<void> disconnect(BridgeNode node) async {}

  List<String> _tokenize(String commandLine) {
    final matches =
        RegExp(r'''(?:[^\s"']+|"[^"]*"|'[^']*')+''').allMatches(commandLine);
    return matches.map((match) {
      final token = match.group(0)!;
      if ((token.startsWith('"') && token.endsWith('"')) ||
          (token.startsWith("'") && token.endsWith("'"))) {
        return token.substring(1, token.length - 1);
      }
      return token;
    }).toList();
  }

  bool _isEscapingPath(String argument) {
    if (argument.startsWith('/') || argument.startsWith('~')) return true;
    return argument.split(Platform.pathSeparator).contains('..');
  }
}
