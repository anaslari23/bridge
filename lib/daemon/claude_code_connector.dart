import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/bridge_models.dart';
import '../core/bridge_protocol.dart';

class ClaudeCodeSessionBusyException implements Exception {
  const ClaudeCodeSessionBusyException();
}

/// A connector that runs tasks through the user's own, already signed-in
/// Claude Code CLI (`claude`) in documented non-interactive mode.
///
/// This is the supported programmatic route into Claude with an account login;
/// the Claude Desktop chat app itself has no documented inbound interface.
/// Each task starts one `claude -p --output-format stream-json --verbose`
/// process (prompt on stdin, not in argv) and resumes the paired session with
/// `--resume` on later tasks.
///
/// Credentials stay in Claude Code's own store. Bridge never reads them, never
/// passes `--dangerously-skip-permissions` or `--bare`, and removes
/// `ANTHROPIC_API_KEY` / `ANTHROPIC_AUTH_TOKEN` from the child environment so a
/// stray API key can never take precedence over the account login. Tool calls
/// that need approval are denied by Claude Code's own policy in headless mode;
/// Bridge only reports the denials.
class ClaudeCodeConnector {
  ClaudeCodeConnector({
    required this.workingDirectory,
    String? sessionId,
    this.executable = 'claude',
    this.taskTimeout = const Duration(minutes: 15),
    this.onNotice,
  }) : _sessionId = validateConfig(
          workingDirectory: workingDirectory,
          sessionId: sessionId,
        ) {
    nodeId = '$nodeIdPrefix${_sessionId ?? 'new'}';
  }

  static const nodeIdPrefix = 'claude-code:';
  static const adapterId = 'claude-code-cli';

  /// Variables that would make Claude Code authenticate with a key instead of
  /// the account login.
  static const strippedEnvironmentKeys = {
    'ANTHROPIC_API_KEY',
    'ANTHROPIC_AUTH_TOKEN',
  };

  final String workingDirectory;
  final String executable;
  final Duration taskTimeout;
  final void Function(String message)? onNotice;

  String? _sessionId;
  String? get sessionId => _sessionId;

  /// Fixed at construction, even before a session exists.
  late final String nodeId;

  Process? _process;
  String? _activeTaskId;
  bool _cancelRequested = false;
  bool _connected = false;

  static Map<String, String> sanitizedEnvironment(Map<String, String> source) =>
      Map<String, String>.from(source)
        ..removeWhere((key, _) => strippedEnvironmentKeys.contains(key));

  /// Returns the validated session ID (or null).
  static String? validateConfig({
    required String workingDirectory,
    String? sessionId,
  }) {
    if (workingDirectory.isEmpty ||
        (!workingDirectory.startsWith('/') &&
            !RegExp(r'^[A-Za-z]:[\\/]').hasMatch(workingDirectory)) ||
        workingDirectory.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
      throw const FormatException('Enter an absolute working directory');
    }
    if (!Directory(workingDirectory).existsSync()) {
      throw const FormatException('The working directory does not exist');
    }
    if (sessionId == null || sessionId.isEmpty) return null;
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$').hasMatch(sessionId)) {
      throw const FormatException('Enter a valid Claude Code session ID');
    }
    return sessionId;
  }

  Map<String, String> get _environment =>
      sanitizedEnvironment(Platform.environment);

  /// Confirms the CLI is installed and signed in with an account (not an API
  /// key), using the read-only `claude --version` and `claude auth status`.
  Future<BridgeNode> connect() async {
    final String version;
    try {
      final result = await Process.run(
        executable,
        const ['--version'],
        workingDirectory: workingDirectory,
        environment: _environment,
        includeParentEnvironment: false,
      ).timeout(const Duration(seconds: 20));
      if (result.exitCode != 0) {
        throw StateError('The Claude Code CLI did not start '
            '(exit ${result.exitCode}): ${_tail(result.stderr.toString())}');
      }
      version = result.stdout.toString().trim();

      final auth = await Process.run(
        executable,
        const ['auth', 'status'],
        workingDirectory: workingDirectory,
        environment: _environment,
        includeParentEnvironment: false,
      ).timeout(const Duration(seconds: 20));
      _checkAuth(auth);
    } on ProcessException {
      throw StateError(
          'The Claude Code CLI (claude) was not found on this computer');
    }
    _connected = true;
    return BridgeNode(
      id: nodeId,
      name: 'Claude Code',
      kind: NodeKind.agent,
      detail: _sessionId == null
          ? 'new session in $workingDirectory'
          : '$_sessionId in $workingDirectory',
      adapterId: adapterId,
      adapterVersion: version.isEmpty ? null : version,
      health: 'connected',
      capabilities: const ['receive_task', 'cancel_task'],
      taskDomains: const ['general', 'coding', 'review'],
    );
  }

  void _checkAuth(ProcessResult auth) {
    Object? status;
    try {
      status = jsonDecode(auth.stdout.toString());
    } on FormatException {
      status = null;
    }
    if (auth.exitCode != 0 || status is! Map || status['loggedIn'] != true) {
      throw StateError(
          'Claude Code is not signed in. Run claude and sign in with your '
          'Claude account first.');
    }
    final method = status['authMethod'];
    if (method is String && method.toLowerCase().contains('api')) {
      throw StateError('Claude Code is signed in with an API key. Bridge only '
          'uses account logins; sign in with your Claude account instead.');
    }
  }

  Future<String> sendTask(BridgeTask task, {String? prompt}) async {
    if (!_connected) throw StateError('Claude Code is not connected');
    if (task.targetNodeId != nodeId) {
      throw ArgumentError('Task is addressed to another Claude Code session');
    }
    if (_activeTaskId != null) throw const ClaudeCodeSessionBusyException();
    _activeTaskId = task.id;
    _cancelRequested = false;
    try {
      final taskText = prompt ?? BridgeProtocol.taskPrompt(task.instruction);
      final message = '[Brigade Bridge context]\n'
          'projectId: ${task.projectId}\n\n'
          '$taskText';

      final args = <String>[
        '-p',
        '--output-format',
        'stream-json',
        '--verbose',
        if (_sessionId != null) ...['--resume', _sessionId!],
      ];
      final Process process;
      try {
        process = await Process.start(
          executable,
          args,
          workingDirectory: workingDirectory,
          environment: _environment,
          includeParentEnvironment: false,
        );
      } on ProcessException {
        _connected = false;
        throw StateError(
            'The Claude Code CLI (claude) was not found on this computer');
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
          onNotice?.call('Claude Code: ${_truncate(line)}');
        },
        onDone: stderrDone.complete,
        onError: (_) => stderrDone.complete(),
      );

      process.stdin.write(message);
      unawaited(process.stdin.close().catchError((_) {}));

      final exitCode = await process.exitCode.timeout(
        taskTimeout,
        onTimeout: () {
          process.kill(ProcessSignal.sigterm);
          throw TimeoutException('Claude Code run timed out', taskTimeout);
        },
      );
      await Future.wait([stdoutDone.future, stderrDone.future])
          .timeout(const Duration(seconds: 5), onTimeout: () => const []);

      if (_cancelRequested) throw StateError('Claude Code run was canceled');
      return _resolve(run, exitCode);
    } finally {
      _process = null;
      _activeTaskId = null;
    }
  }

  Future<void> cancelTask(String bridgeTaskId) async {
    if (_activeTaskId != bridgeTaskId) return;
    _cancelRequested = true;
    // SIGINT ends the turn; SIGTERM would leave it unfinished (per the docs).
    _process?.kill(ProcessSignal.sigint);
  }

  Future<void> close() async {
    _connected = false;
    _cancelRequested = true;
    _process?.kill(ProcessSignal.sigint);
  }

  void _onStdoutLine(String line, _RunState run) {
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      return;
    }
    if (decoded is! Map) return;
    _learnSession(decoded['session_id']);
    switch (decoded['type']) {
      case 'system':
        if (decoded['subtype'] == 'permission_denied') {
          run.denials++;
          final tool = decoded['tool_name'];
          onNotice?.call('Claude Code denied a tool call that needs approval'
              '${tool is String ? ' ($tool)' : ''}; allow it in Claude Code '
              'settings if intended');
        }
      case 'assistant':
        final message = decoded['message'];
        final content = message is Map ? message['content'] : null;
        if (content is List) {
          for (final block in content) {
            if (block is Map &&
                block['type'] == 'text' &&
                block['text'] is String) {
              run.assistantText.add(block['text'] as String);
            }
          }
        }
      case 'result':
        run.result = Map<String, dynamic>.from(decoded);
    }
  }

  void _learnSession(Object? id) {
    if (_sessionId == null &&
        id is String &&
        RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$').hasMatch(id)) {
      _sessionId = id; // later tasks resume the same session
    }
  }

  String _resolve(_RunState run, int exitCode) {
    final result = run.result;
    if (result != null) {
      final text = result['result'];
      if (result['is_error'] != true && result['subtype'] == 'success') {
        final answer = (text is String && text.trim().isNotEmpty)
            ? text.trim()
            : run.assistantText.join('\n').trim();
        if (answer.isEmpty) {
          throw const FormatException('Claude Code returned no response text');
        }
        return answer;
      }
      throw StateError('Claude Code run failed (${result['subtype'] ?? 'error'})'
          '${text is String && text.isNotEmpty ? ': ${_truncate(text)}' : ''}'
          '${run.denials > 0 ? ' [${run.denials} tool call(s) denied]' : ''}');
    }
    if (exitCode != 0) {
      throw StateError('Claude Code CLI exited with code $exitCode'
          '${run.stderr.isEmpty ? '' : ': ${_tail(run.stderr.join('\n'))}'}');
    }
    throw const FormatException('Claude Code produced no result');
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
  final List<String> assistantText = [];
  final List<String> stderr = [];
  int denials = 0;
  Map<String, dynamic>? result;
}
