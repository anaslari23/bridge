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
  static Future<bool> isAccessibilityEnabled() async =>
      await _channel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;
  static Future<bool> isScreenRecordingEnabled() async =>
      await _channel.invokeMethod<bool>('isScreenRecordingEnabled') ?? false;
  static Future<bool> requestScreenRecording() async =>
      await _channel.invokeMethod<bool>('requestScreenRecording') ?? false;
  static Future<void> setClickThrough(bool enabled) =>
      _channel.invokeMethod('setClickThrough', enabled);
  static Future<bool> isClickThroughEnabled() async =>
      await _channel.invokeMethod<bool>('isClickThroughEnabled') ?? false;
  static Future<void> setOpacity(double opacity) =>
      _channel.invokeMethod('setOpacity', opacity);
  static Future<double> getOpacity() async =>
      await _channel.invokeMethod<double>('getOpacity') ?? 1.0;
  static Future<void> setLaunchAtLogin(bool enabled) =>
      _channel.invokeMethod('setLaunchAtLogin', enabled);
  static Future<bool> isLaunchAtLoginEnabled() async =>
      await _channel.invokeMethod<bool>('isLaunchAtLoginEnabled') ?? false;
  static Future<bool> isOnboardingComplete() async =>
      await _channel.invokeMethod<bool>('isOnboardingComplete') ?? false;
  static Future<void> setOnboardingComplete(bool complete) =>
      _channel.invokeMethod('setOnboardingComplete', complete);
  static Future<String?> chooseDirectory() =>
      _channel.invokeMethod<String?>('chooseDirectory');
  static Future<List<String>?> chooseFiles() async {
    final result = await _channel.invokeMethod<List<dynamic>>('chooseFiles');
    return result?.whereType<String>().toList();
  }

  static Future<bool> openFile(String path) async =>
      await _channel.invokeMethod<bool>('openFile', path) ?? false;
  static Future<Uint8List?> captureWindow(String id) =>
      _channel.invokeMethod<Uint8List>('captureWindow', id);

  static Future<List<Map<String, dynamic>>> discoverWindows() async {
    final result =
        await _channel.invokeMethod<List<dynamic>>('discoverWindows');
    return (result ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<Map<String, dynamic>> inspectWindow(String id) async =>
      Map<String, dynamic>.from(await _channel
              .invokeMethod<Map<dynamic, dynamic>>('inspectWindow', id) ??
          {});

  static Future<bool> focusWindow(String id) async =>
      await _channel.invokeMethod<bool>('focusWindow', id) ?? false;

  /// Executes only a named, permission-approved action on the focused control
  /// in a verified window. The native side rejects stale window IDs.
  static Future<bool> setFocusedText(String windowId, String text) async =>
      await _channel.invokeMethod<bool>('setFocusedText', {
        'id': windowId,
        'text': text,
      }) ??
      false;

  static Future<bool> pressFocusedControl(String windowId) async =>
      await _channel.invokeMethod<bool>('pressFocusedControl', windowId) ??
      false;
}
