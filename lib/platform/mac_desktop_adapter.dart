import '../core/bridge_models.dart';
import '../core/node_adapter.dart';
import 'bridge_channel.dart';

/// Adapter for windows exposed by macOS Accessibility. It deliberately keeps
/// focus/inspection separate from text input; callers must pass through the
/// daemon permission manager before invoking `execute` for a sensitive task.
class MacDesktopAdapter implements NodeAdapter {
  @override
  String get id => 'macos-accessibility';

  @override
  Future<List<BridgeNode>> discover() async {
    try {
      final windows = await BridgeChannel.discoverWindows();
      return windows
          .map((window) => BridgeNode(
                id: window['id'] as String,
                name: window['name'] as String? ?? 'Desktop app',
                kind: NodeKind.desktop,
                detail: window['title'] as String? ?? 'Untitled window',
                processId: window['pid'] as int?,
                windowId: window['id'] as String?,
                adapterId: id,
                adapterVersion: 'v1',
                capabilities: const [
                  'inspect_window',
                  'focus_window',
                  'set_focused_text',
                  'press_focused_control'
                ],
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> connect(BridgeNode node) async {
    await BridgeChannel.inspectWindow(node.id);
  }

  @override
  Future<String> inspect(BridgeNode node) async {
    final result = await BridgeChannel.inspectWindow(node.id);
    return result.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('\n');
  }

  @override
  Future<String> execute(BridgeTask task) async {
    final focused =
        await BridgeChannel.setFocusedText(task.targetNodeId, task.instruction);
    if (!focused) throw StateError('No verified focused control accepted text');
    return 'Text delivered to ${task.targetNodeId}';
  }

  @override
  Future<String?> readOutput(BridgeTask task) async => null;

  @override
  Future<void> waitForCompletion(BridgeTask task) async {}

  @override
  Future<void> cancel(String taskId) async {}

  @override
  Future<void> disconnect(BridgeNode node) async {}
}
