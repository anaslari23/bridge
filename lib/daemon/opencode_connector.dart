import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/bridge_models.dart';
import '../core/bridge_protocol.dart';

class OpenCodeSessionBusyException implements Exception {
  const OpenCodeSessionBusyException();
}

/// A connector for one OpenCode session explicitly selected by the user.
///
/// This class never starts an OpenCode process, discovers servers, or lists
/// sessions. It only sends requests to the loopback URL and session ID passed
/// to its constructor.
class OpenCodeConnector {
  OpenCodeConnector({
    required String serverUrl,
    required this.sessionId,
    HttpClient Function()? httpClientFactory,
  })  : serverUri = validateEndpoint(
          serverUrl: serverUrl,
          sessionId: sessionId,
        ),
        _client = (httpClientFactory ?? HttpClient.new)();

  final Uri serverUri;
  final String sessionId;
  final HttpClient _client;
  final Set<String> _activeTaskIds = <String>{};
  bool _connected = false;

  static Uri validateEndpoint({
    required String serverUrl,
    required String sessionId,
  }) {
    if (sessionId.isEmpty ||
        sessionId.length > 256 ||
        sessionId.contains('/') ||
        sessionId.contains('\\') ||
        sessionId.contains(RegExp(r'\s')) ||
        sessionId.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
      throw const FormatException('Enter a valid OpenCode session ID');
    }

    final uri = Uri.tryParse(serverUrl.trim());
    if (uri == null ||
        uri.scheme != 'http' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        !uri.hasPort ||
        uri.port < 1 ||
        uri.port > 65535) {
      throw const FormatException(
          'Use an HTTP loopback URL with an explicit valid port');
    }
    final host = uri.host.toLowerCase();
    final address = InternetAddress.tryParse(host);
    if (host != 'localhost' && !(address?.isLoopback ?? false)) {
      throw const FormatException('OpenCode server must be on this computer');
    }
    return uri.replace(path: '', query: null, fragment: null);
  }

  Uri _endpoint(String path) => serverUri.resolve(path);

  Future<BridgeNode> connect() async {
    final health = await _getJson(_endpoint('/global/health'));
    if (health['healthy'] != true) {
      throw const HttpException('OpenCode server did not report healthy');
    }

    final session =
        await _getJson(_endpoint('/session/${Uri.encodeComponent(sessionId)}'));
    if (session['id'] != sessionId) {
      throw const HttpException('The selected OpenCode session was not found');
    }
    _connected = true;
    return BridgeNode(
      id: 'opencode:$sessionId',
      name: 'OpenCode',
      kind: NodeKind.agent,
      detail: '$sessionId at ${serverUri.host}:${serverUri.port}',
      adapterId: 'opencode-http',
      adapterVersion: health['version'] as String?,
      health: 'connected',
      capabilities: const ['receive_task', 'cancel_task'],
      taskDomains: const ['general', 'coding', 'review'],
    );
  }

  Future<String> sendTask(BridgeTask task, {String? prompt}) async {
    if (!_connected) throw StateError('OpenCode session is not connected');
    if (task.targetNodeId != 'opencode:$sessionId') {
      throw ArgumentError('Task is addressed to another OpenCode session');
    }
    if (_activeTaskIds.isNotEmpty) {
      throw const OpenCodeSessionBusyException();
    }
    if (!_activeTaskIds.add(task.id)) {
      throw StateError('OpenCode task is already active');
    }
    try {
      final taskText = prompt ?? BridgeProtocol.taskPrompt(task.instruction);
      final message = '[Brigade Bridge context]\n'
          'projectId: ${task.projectId}\n\n'
          '$taskText';
      final response = await _postJson(
        _endpoint('/session/${Uri.encodeComponent(sessionId)}/message'),
        {
          'parts': [
            {
              'type': 'text',
              'text': message,
            }
          ],
        },
      );
      final info = response['info'];
      if (info is! Map || info['role'] != 'assistant') {
        throw const FormatException(
            'OpenCode returned a non-assistant message');
      }
      final parts = response['parts'];
      if (parts is! List) {
        throw const FormatException('OpenCode returned no message parts');
      }
      final text = parts
          .whereType<Map>()
          .where((part) => part['type'] == 'text' && part['text'] is String)
          .map((part) => part['text'] as String)
          .join('\n')
          .trim();
      if (text.isEmpty) {
        throw const FormatException('OpenCode returned no assistant text');
      }
      return text;
    } finally {
      _activeTaskIds.remove(task.id);
    }
  }

  Future<void> cancelTask(String bridgeTaskId) async {
    if (!_activeTaskIds.contains(bridgeTaskId)) return;
    final result = await _requestData(
      'POST',
      _endpoint('/session/${Uri.encodeComponent(sessionId)}/abort'),
    );
    if (result != true) {
      throw const HttpException('OpenCode did not abort the active session');
    }
  }

  Future<void> close() async {
    _connected = false;
    _activeTaskIds.clear();
    _client.close(force: true);
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) => _requestJson('GET', uri);

  Future<Map<String, dynamic>> _postJson(
    Uri uri,
    Map<String, dynamic> body,
  ) =>
      _requestJson('POST', uri, body: body);

  Future<Map<String, dynamic>> _requestJson(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
  }) async {
    final decoded = await _requestData(method, uri, body: body);
    if (decoded is! Map) {
      throw const FormatException('OpenCode returned an invalid JSON object');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<Object?> _requestData(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
  }) async {
    final request = await _client.openUrl(method, uri).timeout(
          const Duration(seconds: 10),
        );
    request.followRedirects = false;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close().timeout(const Duration(minutes: 3));
    final responseText = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'OpenCode request failed with HTTP ${response.statusCode}',
        uri: uri,
      );
    }
    final decoded = jsonDecode(responseText);
    return decoded;
  }
}
