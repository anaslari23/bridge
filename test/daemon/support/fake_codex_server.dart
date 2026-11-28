import 'dart:convert';
import 'dart:io';

/// A simulated `codex app-server` speaking the documented JSON-RPC subset.
class FakeCodexServer {
  FakeCodexServer._(this._http);

  final HttpServer _http;
  final List<Map<String, dynamic>> received = [];
  final List<Map<String, dynamic>> responsesFromClient = [];
  WebSocket? socket;

  Object? account = {'type': 'chatgpt', 'planType': 'pro'};
  bool requiresOpenaiAuth = true;
  String knownThread = 'thr_1';
  int overloadFirstTurnStarts = 0;
  String? lastTurnText;

  /// Called for each `turn/start`; drives the notifications for a turn.
  void Function(FakeCodexServer server, int requestId)? onTurnStart;

  static Future<FakeCodexServer> start() async {
    final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final server = FakeCodexServer._(http);
    http.transform(WebSocketTransformer()).listen(server._onSocket);
    return server;
  }

  String get url => 'ws://127.0.0.1:${_http.port}';

  Future<void> close() async {
    await socket?.close();
    await _http.close(force: true);
  }

  void _onSocket(WebSocket ws) {
    socket = ws;
    ws.listen((frame) {
      final msg = Map<String, dynamic>.from(jsonDecode(frame as String) as Map);
      if (msg.containsKey('method')) {
        received.add(msg);
        _handle(msg);
      } else {
        responsesFromClient.add(msg);
      }
    });
  }

  void send(Map<String, Object?> message) => socket!.add(jsonEncode(message));

  void _handle(Map<String, dynamic> msg) {
    final id = msg['id'];
    switch (msg['method']) {
      case 'initialize':
        send({
          'id': id,
          'result': {'userAgent': 'codex-test/1.0', 'platformOs': 'linux'},
        });
      case 'account/read':
        send({
          'id': id,
          'result': {
            'account': account,
            'requiresOpenaiAuth': requiresOpenaiAuth,
          },
        });
      case 'thread/resume':
        final requested = (msg['params'] as Map)['threadId'];
        if (requested != knownThread) {
          send({
            'id': id,
            'error': {'code': -32600, 'message': 'thread not found'},
          });
        } else {
          send({
            'id': id,
            'result': {
              'thread': {'id': requested},
            },
          });
        }
      case 'turn/start':
        if (overloadFirstTurnStarts > 0) {
          overloadFirstTurnStarts--;
          send({
            'id': id,
            'error': {
              'code': -32001,
              'message': 'Server overloaded; retry later.',
            },
          });
          return;
        }
        final input = (msg['params'] as Map)['input'] as List;
        lastTurnText = (input.first as Map)['text'] as String;
        send({
          'id': id,
          'result': {
            'turn': {
              'id': 'turn_1',
              'status': 'inProgress',
              'items': [],
              'error': null,
            },
          },
        });
        onTurnStart?.call(this, id as int);
      case 'turn/interrupt':
        send({'id': id, 'result': {}});
        send({
          'method': 'turn/completed',
          'params': {
            'threadId': 'thr_1',
            'turn': {'id': 'turn_1', 'status': 'interrupted'},
          },
        });
    }
  }

  void agentMessage(String text, {String? phase, String id = 'item_1'}) {
    send({
      'method': 'item/completed',
      'params': {
        'threadId': 'thr_1',
        'turnId': 'turn_1',
        'item': {
          'type': 'agentMessage',
          'id': id,
          'text': text,
          if (phase != null) 'phase': phase,
        },
      },
    });
  }

  void turnCompleted(String status, {String? errorMessage}) {
    send({
      'method': 'turn/completed',
      'params': {
        'threadId': 'thr_1',
        'turn': {
          'id': 'turn_1',
          'status': status,
          if (errorMessage != null) 'error': {'message': errorMessage},
        },
      },
    });
  }
}
