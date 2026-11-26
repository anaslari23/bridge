import '../core/bridge_models.dart';
import 'permission_manager.dart';

typedef DesktopExecutor = Future<bool> Function(String action, String nodeId, String? value);

/// Keeps native desktop automation behind the same approval boundary as agent
/// task dispatch. The executor is injected so the daemon remains testable and
/// the platform channel never becomes an implicit permission bypass.
class DesktopActionRouter {
  DesktopActionRouter(this.permissions, this.executor);
  final PermissionManager permissions;
  final DesktopExecutor executor;

  Future<bool> execute({required String nodeId, required String action, String? value}) async {
    final task = BridgeTask(
      id: 'desktop-${DateTime.now().microsecondsSinceEpoch}',
      sourceNodeId: 'user',
      targetNodeId: nodeId,
      instruction: value ?? action,
    );
    if (!await permissions.checkAction(nodeId, action, task)) return false;
    return executor(action, nodeId, value);
  }
}
