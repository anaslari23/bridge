import 'dart:async';
import 'package:flutter/services.dart';

class BridgeChannel {
  static const _channel = MethodChannel('com.brigade.bridge/channel');

  static final _hotKeyController = StreamController<void>.broadcast();
  static Stream<void> get onHotKeyFired => _hotKeyController.stream;

  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'hotkey_fired') {
        _hotKeyController.add(null);
      }
    });
  }

  static Future<void> showPanel() => _channel.invokeMethod('showPanel');
  static Future<void> hidePanel() => _channel.invokeMethod('hidePanel');
  static Future<void> setStatusBadge(String state) =>
      _channel.invokeMethod('setStatusBadge', state);
  static Future<void> requestAccessibility() =>
      _channel.invokeMethod('requestAccessibility');
}
