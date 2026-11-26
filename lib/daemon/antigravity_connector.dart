import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/bridge_models.dart';
import '../core/bridge_protocol.dart';

class AntigravitySessionBusyException implements Exception {
  const AntigravitySessionBusyException();
}

/// A connector that runs tasks through the user's own, already signed-in
/// Antigravity CLI (`agy`) in headless mode.
///
/// Unlike the OpenCode and Codex connectors there is no long-lived server to
/// attach to, so each task starts one `agy` process using the documented
/// `--input-format stream-json --output-format stream-json` mode and resumes
/// the paired conversation with `--conversation`. Credentials stay in
/// Antigravity's own cache; Bridge never reads, stores, or passes them, and
/// never passes `--dangerously-skip-permissions`, so actions Antigravity would
/// ask about are soft-denied by Antigravity's own policy (its notices are
/// forwarded to [onNotice]).
///
/// The working directory is chosen explicitly by the user. The prompt is sent
/// on stdin, not in the argument list, so it does not appear in process
/// listings.
class AntigravityConnector {
  AntigravityConnector({
    required this.workingDirectory,
    String? conversationId,
    this.executable = 'agy',
    this.taskTimeout = const Duration(minutes: 15),
    this.onNotice,
  }) : _conversationId = validateConfig(
          workingDirectory: workingDirectory,
          conversationId: conversationId,
        ) {
    nodeId = '$nodeIdPrefix${_conversationId ?? 'new'}';
  }

  static const nodeIdPrefix = 'antigravity:';
  static const adapterId = 'antigravity-cli';

  final String workingDirectory;
  final String executable;
  final Duration taskTimeout;
  final void Function(String message)? onNotice;

  /// Null until a first task creates (or the user supplies) a conversation.
  String? _conversationId;
  String? get conversationId => _conversationId;

  /// Fixed at construction, even before a conversation exists.
  late final String nodeId;

  Process? _process;
  String? _activeTaskId;
  bool _cancelRequested = false;
  bool _connected = false;

  /// Returns the validated conversation ID (or null).
  static String? validateConfig({
    required String workingDirectory,
    String? conversationId,
  }) {
    if (workingDirectory.isEmpty ||
        (!workingDirectory.startsWith('/') &&
            !_isWindowsAbsolute(workingDirectory)) ||
        workingDirectory.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
      throw const FormatException('Enter an absolute working directory');
    }
    if (!Directory(workingDirectory).existsSync()) {
      throw const FormatException('The working directory does not exist');
    }
    if (conversationId == null || conversationId.isEmpty) return null;
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(conversationId)) {
      throw const FormatException('Enter a valid Antigravity conversation ID');
    }
    return conversationId;
  }

  static bool _isWindowsAbsolute(String path) =>
      RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path);

  /// Confirms the CLI is installed and can start, using the read-only
  /// `agy models` command. It sends no prompt.
  Future<BridgeNode> connect() async {
    final ProcessResult result;
    try {
      result = await Process.run(
        executable,
        const ['models'],
        workingDirectory: workingDirectory,
      ).timeout(const Duration(seconds: 20));
    } on ProcessException {
      throw StateError('The Antigravity CLI (agy) was not found on this computer');
    }
    if (result.exitCode != 0) {
      throw StateError(
        'The Antigravity CLI is not ready (exit ${result.exitCode}): '
        '${_tail(result.stderr.toString())}. '
        'Sign in by running agy interactively once.',
      );
    }
    _connected = true;
    return BridgeNode(
      id: nodeId,
      name: 'Antigravity',
      kind: NodeKind.agent,
      detail: _conversationId == null
          ? 'new conversation in $workingDirectory'
          : '$_conversationId in $workingDirectory',
      adapterId: adapterId,
      health: 'connected',
      capabilities: const ['receive_task', 'cancel_task'],
      taskDomains: const ['general', 'coding', 'review'],
    );
  }

  Future<String> sendTask(BridgeTask task, {String? prompt}) async {
    if (!_connected) throw StateError('Antigravity is not connected');
    if (task.targetNodeId != nodeId) {
      throw ArgumentError('Task is addressed to another Antigravity session');
    }
    if (_activeTaskId != null) throw const AntigravitySessionBusyException();
    _activeTaskId = task.id;
    _cancelRequested = false;
    try {
      final taskText = prompt ?? BridgeProtocol.taskPrompt(task.instruction);
      final message = '[Brigade Bridge context]\n'
          'projectId: ${task.projectId}\n\n'
          '$taskText';

      final args = <String>[
        '--input-format',
        'stream-json',
        '--output-format',
        'stream-json',
        if (_conversationId != null) ...['--conversation', _conversationId!],
        '--print-timeout',
        '${taskTimeout.inSeconds}s',
      ];
      final Process process;
      try {
        process = await Process.start(
          executable,
          args,
          workingDirectory: workingDirectory,
        );
      } on ProcessException {
        _connected = false;
        throw StateError(
            'The Antigravity CLI (agy) was not found on this computer');
      }
      _process = process;

      final run = _RunState();
      final stdoutDone = Completer<void>();
      final stderrDone = Completer<void>();
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) => _onStdoutLine(line, run),
            onDone: stdoutDone.complete,
            onError: (_) => stdoutDone.complete(),
          );
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (line.trim().isEmpty) return;
          run.stderr.add(line);
          if (run.stderr.length > 20) run.stderr.removeAt(0);
          onNotice?.call('Antigravity: ${_truncate(line)}');
        },
        onDone: stderrDone.complete,
        onError: (_) => stderrDone.complete(),
      );

      process.stdin.writeln(jsonEncode({
        'event': 'user',
        'message': {'content': message},
      }));
      unawaited(process.stdin.close().catchError((_) {}));

      final exitCode = await process.exitCode.timeout(
        taskTimeout + const Duration(seconds: 30),
        onTimeout: () {
          process.kill(ProcessSignal.sigterm);
          throw TimeoutException('Antigravity run timed out', taskTimeout);
        },
      );
      await Future.wait([stdoutDone.future, stderrDone.future])
          .timeout(const Duration(seconds: 5), onTimeout: () => const []);

      if (_cancelRequested) throw StateError('Antigravity run was canceled');
      return _resolve(run, exitCode);
    } finally {
      _process = null;
      _activeTaskId = null;
    }
  }

  Future<void> cancelTask(String bridgeTaskId) async {
    if (_activeTaskId != bridgeTaskId) return;
    _cancelRequested = true;
    _process?.kill(ProcessSignal.sigint); // documented as INTERRUPTED
  }

  Future<void> close() async {
    _connected = false;
    _cancelRequested = true;
    _process?.kill(ProcessSignal.sigterm);
  }

  void _onStdoutLine(String line, _RunState run) {
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      return;
    }
    if (decoded is! Map) return;
    switch (decoded['event']) {
      case 'init':
        _learnConversation(decoded['conversation_id']);
      case 'step_update':
        final step = decoded['step_update'];
        if (step is Map &&
            step['step_type'] == 'agent_response' &&
            step['text_delta'] is String) {
          run.deltas.write(step['text_delta'] as String);
        }
      case 'result':
        final result = decoded['result'];
        if (result is Map) {
          run.result = Map<String, dynamic>.from(result);
          _learnConversation(result['conversation_id']);
        }
    }
  }

  void _learnConversation(Object? id) {
    if (_conversationId == null &&
        id is String &&
        RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id)) {
      _conversationId = id; // later tasks resume the same conversation
    }
  }

  String _resolve(_RunState run, int exitCode) {
    final result = run.result;
    if (result != null) {
      final status = result['status'];
      if (status == 'SUCCESS') {
        final response = result['response'];
        final text = (response is String && response.trim().isNotEmpty)
            ? response.trim()
            : run.deltas.toString().trim();
        if (text.isEmpty) {
          throw const FormatException('Antigravity returned no response text');
        }
        return text;
      }
      final error = result['error'];
      throw StateError('Antigravity run ended with ${status ?? 'no status'}'
          '${error is String && error.isNotEmpty ? ': ${_truncate(error)}' : ''}');
    }
    if (exitCode != 0) {
      throw StateError('Antigravity CLI exited with code $exitCode'
          '${run.stderr.isEmpty ? '' : ': ${_tail(run.stderr.join('\n'))}'}');
    }
    throw const FormatException('Antigravity produced no result');
  }

  static String _truncate(String text) =>
      text.length <= 300 ? text : '${text.substring(0, 300)}…';

  static String _tail(String text) {
    final trimmed = text.trim();
    return trimmed.length <= 400
        ? trimmed
        : '…${trimmed.substring(trimmed.length - 400)}';
  }
}

class _RunState {
  final StringBuffer deltas = StringBuffer();
  final List<String> stderr = [];
  Map<String, dynamic>? result;
}
