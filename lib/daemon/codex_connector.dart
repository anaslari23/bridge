import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/bridge_models.dart';
import '../core/bridge_protocol.dart';

class CodexSessionBusyException implements Exception {
  const CodexSessionBusyException();
}

class CodexRpcException implements Exception {
  CodexRpcException(this.code, this.message);
  final int code;
  final String message;

  @override
  String toString() => 'Codex request failed ($code): $message';
}

/// A connector for one Codex thread explicitly selected by the user.
///
/// It speaks the documented Codex app-server JSON-RPC protocol over a
/// loopback WebSocket that the user started themselves, for example
/// `codex app-server --listen ws://127.0.0.1:4500`. Codex keeps using its own
/// signed-in account; this class never reads, stores, or sends credentials.
///
/// It never starts Codex, discovers servers, or lists threads. It only
/// resumes the thread ID passed to its constructor. Codex approval requests
/// are declined automatically because Bridge does not expose them, so any
/// approval must be granted inside Codex itself beforehand (for example by the
/// thread's own approval policy).
class CodexConnector {
  CodexConnector({
    required String serverUrl,
    required this.threadId,
    Duration requestTimeout = const Duration(seconds: 15),
    Duration turnTimeout = const Duration(minutes: 10),
    Duration retryBaseDelay = const Duration(milliseconds: 250),
    this.onNotice,
  })  : serverUri = validateEndpoint(serverUrl: serverUrl, threadId: threadId),
        _requestTimeout = requestTimeout,
        _turnTimeout = turnTimeout,
        _retryBaseDelay = retryBaseDelay;

  static const nodeIdPrefix = 'codex:';
  static const adapterId = 'codex-app-server';

  final Uri serverUri;
  final String threadId;
  final void Function(String message)? onNotice;
  final Duration _requestTimeout;
  final Duration _turnTimeout;
  final Duration _retryBaseDelay;

  WebSocket? _socket;
  int _nextId = 0;
  final Map<int, Completer<Object?>> _pending = {};
  final Completer<void> _closed = Completer<void>();
  _ActiveTurn? _active;
  bool _connected = false;

  /// Completes when the app-server connection ends for any reason.
  Future<void> get closed => _closed.future;

  String get nodeId => '$nodeIdPrefix$threadId';

  static Uri validateEndpoint({
    required String serverUrl,
    required String threadId,
  }) {
    if (threadId.isEmpty ||
        threadId.length > 256 ||
        threadId.contains('/') ||
        threadId.contains('\\') ||
        threadId.contains(RegExp(r'\s')) ||
        threadId.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
      throw const FormatException('Enter a valid Codex thread ID');
    }

    final uri = Uri.tryParse(serverUrl.trim());
    if (uri == null ||
        uri.scheme != 'ws' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        !uri.hasPort ||
        uri.port < 1 ||
        uri.port > 65535) {
      throw const FormatException(
          'Use a ws:// loopback URL with an explicit valid port');
    }
    final host = uri.host.toLowerCase();
    final address = InternetAddress.tryParse(host);
    if (host != 'localhost' && !(address?.isLoopback ?? false)) {
      throw const FormatException('Codex server must be on this computer');
    }
    return uri.replace(path: '', query: null, fragment: null);
  }

  Future<BridgeNode> connect() async {
    final socket = await WebSocket.connect(serverUri.toString())
        .timeout(const Duration(seconds: 10));
    _socket = socket;
    socket.listen(
      _onFrame,
      onError: (_) => _shutdown(),
      onDone: _shutdown,
      cancelOnError: true,
    );

    try {
      final init = await _request('initialize', {
        'clientInfo': {
          'name': 'brigade_bridge',
          'title': 'Brigade Bridge',
          'version': '0.1.0',
        },
      });
      _send({'method': 'initialized'});

      final account = await _request('account/read', {'refreshToken': false});
      if (account is Map &&
          account['account'] == null &&
          account['requiresOpenaiAuth'] == true) {
        throw StateError('Codex is not signed in. Sign in inside Codex first.');
      }

      final resumed = await _request('thread/resume', {
        'threadId': threadId,
        'excludeTurns': true,
      });
      final thread = resumed is Map ? resumed['thread'] : null;
      if (thread is! Map || thread['id'] != threadId) {
        throw const FormatException(
            'The selected Codex thread was not found');
      }

      _connected = true;
      return BridgeNode(
        id: nodeId,
        name: 'Codex',
        kind: NodeKind.agent,
        detail: '$threadId at ${serverUri.host}:${serverUri.port}',
        adapterId: adapterId,
        adapterVersion: init is Map ? init['userAgent'] as String? : null,
        health: 'connected',
        capabilities: const ['receive_task', 'cancel_task'],
        taskDomains: const ['general', 'coding', 'review'],
      );
    } catch (_) {
      await close();
      rethrow;
    }
  }

  Future<String> sendTask(BridgeTask task, {String? prompt}) async {
    if (!_connected) throw StateError('Codex thread is not connected');
    if (task.targetNodeId != nodeId) {
      throw ArgumentError('Task is addressed to another Codex thread');
    }
    if (_active != null) throw const CodexSessionBusyException();

    final turn = _ActiveTurn(task.id);
    _active = turn;
    try {
      final taskText = prompt ?? BridgeProtocol.taskPrompt(task.instruction);
      final message = '[Brigade Bridge context]\n'
          'projectId: ${task.projectId}\n\n'
          '$taskText';
      final started = await _request('turn/start', {
        'threadId': threadId,
        'input': [
          {'type': 'text', 'text': message},
        ],
      });
      final startedTurn = started is Map ? started['turn'] : null;
      final turnId = startedTurn is Map ? startedTurn['id'] : null;
      if (turnId is! String || turnId.isEmpty) {
        throw const FormatException('Codex did not return a turn ID');
      }
      turn.turnId ??= turnId;
      if (turn.cancelRequested) {
        unawaited(_interrupt(turn).catchError((_) {}));
      }
      return await turn.result.future.timeout(_turnTimeout, onTimeout: () {
        unawaited(_interrupt(turn).catchError((_) {}));
        throw TimeoutException('Codex turn timed out', _turnTimeout);
      });
    } finally {
      if (identical(_active, turn)) _active = null;
    }
  }

  Future<void> cancelTask(String bridgeTaskId) async {
    final turn = _active;
    if (turn == null || turn.taskId != bridgeTaskId) return;
    turn.cancelRequested = true;
    if (turn.turnId == null) return; // sent as soon as turn/start returns
    await _interrupt(turn);
  }

  Future<void> close() async {
    _connected = false;
    final socket = _socket;
    _socket = null;
    _shutdown();
    try {
      await socket?.close();
    } catch (_) {}
  }

  Future<void> _interrupt(_ActiveTurn turn) async {
    final id = turn.turnId;
    if (id == null || turn.interruptSent) return;
    turn.interruptSent = true;
    await _request('turn/interrupt', {'threadId': threadId, 'turnId': id});
  }

  void _shutdown() {
    _connected = false;
    if (!_closed.isCompleted) _closed.complete();
    for (final pending in _pending.values) {
      if (!pending.isCompleted) {
        pending.completeError(StateError('Codex connection closed'));
      }
    }
    _pending.clear();
    final turn = _active;
    if (turn != null && !turn.result.isCompleted) {
      turn.result.completeError(StateError('Codex connection closed'));
    }
  }

  void _send(Map<String, Object?> message) {
    final socket = _socket;
    if (socket == null) throw StateError('Codex connection is closed');
    socket.add(jsonEncode(message));
  }

  Future<Object?> _request(String method, Map<String, Object?> params) async {
    for (var attempt = 0;; attempt++) {
      try {
        return await _requestOnce(method, params);
      } on CodexRpcException catch (error) {
        // -32001 is documented as "Server overloaded; retry later."
        if (error.code != -32001 || attempt >= 3) rethrow;
        await Future<void>.delayed(_retryBaseDelay * (1 << attempt));
      }
    }
  }

  Future<Object?> _requestOnce(
      String method, Map<String, Object?> params) async {
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    try {
      _send({'method': method, 'id': id, 'params': params});
      return await completer.future.timeout(_requestTimeout);
    } finally {
      _pending.remove(id);
    }
  }

  void _onFrame(dynamic frame) {
    if (frame is! String) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(frame);
    } on FormatException {
      return;
    }
    if (decoded is! Map) return;
    final method = decoded['method'];
    final id = decoded['id'];
    if (method is String && id != null) {
      _onServerRequest(method, id);
    } else if (method is String) {
      final params = decoded['params'];
      _onNotification(
          method, params is Map ? Map<String, dynamic>.from(params) : {});
    } else if (id is int) {
      final pending = _pending[id];
      if (pending == null || pending.isCompleted) return;
      final error = decoded['error'];
      if (error is Map) {
        pending.completeError(CodexRpcException(
          error['code'] is int ? error['code'] as int : -1,
          error['message']?.toString() ?? 'Unknown error',
        ));
      } else {
        pending.complete(decoded['result']);
      }
    }
  }

  /// Bridge never grants Codex approvals. Deny by default so Codex continues
  /// rather than hanging on a prompt nobody can answer.
  void _onServerRequest(String method, Object id) {
    switch (method) {
      case 'item/commandExecution/requestApproval':
      case 'item/fileChange/requestApproval':
        _active?.declinedApprovals++;
        onNotice?.call('Declined Codex approval request ($method)');
        _send({
          'id': id,
          'result': {'decision': 'decline'},
        });
      case 'item/permissions/requestApproval':
        _active?.declinedApprovals++;
        onNotice?.call('Declined Codex permission request');
        _send({
          'id': id,
          'result': {'permissions': <String, Object?>{}},
        });
      default:
        _send({
          'id': id,
          'error': {
            'code': -32601,
            'message': 'Brigade Bridge does not handle $method',
          },
        });
    }
  }

  void _onNotification(String method, Map<String, dynamic> params) {
    final turn = _active;
    if (turn == null) return;
    final notifiedThread = params['threadId'];
    if (notifiedThread is String && notifiedThread != threadId) return;
    final notifiedTurn = params['turnId'];
    if (notifiedTurn is String &&
        turn.turnId != null &&
        notifiedTurn != turn.turnId) {
      return;
    }

    switch (method) {
      case 'turn/started':
        final started = params['turn'];
        if (started is Map && started['id'] is String) {
          turn.turnId ??= started['id'] as String;
        }
      case 'item/agentMessage/delta':
        final itemId = params['itemId'];
        final delta = params['delta'];
        if (itemId is String && delta is String) {
          turn.deltas.putIfAbsent(itemId, StringBuffer.new).write(delta);
        }
      case 'item/completed':
        final item = params['item'];
        if (item is Map &&
            item['type'] == 'agentMessage' &&
            item['text'] is String) {
          turn.messages.add(_AgentMessage(
            item['text'] as String,
            item['phase'] as String?,
          ));
        }
      case 'turn/completed':
        final done = params['turn'];
        if (done is Map) {
          if (done['id'] is String &&
              turn.turnId != null &&
              done['id'] != turn.turnId) {
            return;
          }
          _finish(turn, done);
        }
    }
  }

  void _finish(_ActiveTurn turn, Map done) {
    if (turn.result.isCompleted) return;
    switch (done['status']) {
      case 'completed':
        final text = turn.finalText();
        if (text.isEmpty) {
          turn.result.completeError(
              const FormatException('Codex returned no assistant text'));
        } else {
          turn.result.complete(text);
        }
      case 'interrupted':
        turn.result.completeError(StateError('Codex turn was interrupted'));
      default:
        final error = done['error'];
        var message = error is Map && error['message'] != null
            ? error['message'].toString()
            : 'Codex turn failed';
        if (turn.declinedApprovals > 0) {
          message += ' (Bridge declined ${turn.declinedApprovals} Codex '
              'approval request(s); approve actions inside Codex)';
        }
        turn.result.completeError(StateError(message));
    }
  }
}

class _AgentMessage {
  _AgentMessage(this.text, this.phase);
  final String text;
  final String? phase;
}

class _ActiveTurn {
  _ActiveTurn(this.taskId) {
    // Errors are delivered through the awaiting caller; mark handled so an
    // early failure cannot surface as an unhandled async error.
    result.future.ignore();
  }

  final String taskId;
  final Completer<String> result = Completer<String>();
  final List<_AgentMessage> messages = [];
  final Map<String, StringBuffer> deltas = {};
  String? turnId;
  bool cancelRequested = false;
  bool interruptSent = false;
  int declinedApprovals = 0;

  String finalText() {
    final finals = messages.where((m) => m.phase == 'final_answer');
    final chosen = finals.isNotEmpty
        ? finals.last
        : (messages.isNotEmpty ? messages.last : null);
    if (chosen != null) return chosen.text.trim();
    return deltas.values.map((b) => b.toString()).join('\n').trim();
  }
}
