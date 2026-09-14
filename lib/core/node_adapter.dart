import 'bridge_models.dart';

/// Contract implemented by local integrations. Adapters use the user's
/// existing application session; they never receive or extract API keys.
abstract interface class NodeAdapter {
  String get id;
  Future<List<BridgeNode>> discover();
  Future<void> connect(BridgeNode node);
  Future<String> inspect(BridgeNode node);
  Future<String> execute(BridgeTask task);
  Future<void> cancel(String taskId);
  Future<void> disconnect(BridgeNode node);
}

class LocalSimulationAdapter implements NodeAdapter {
  @override String get id => 'local-simulation';
  @override Future<List<BridgeNode>> discover() async => const [];
  @override Future<void> connect(BridgeNode node) async {}
  @override Future<String> inspect(BridgeNode node) async => 'Local node ready: ${node.name}';
  @override Future<String> execute(BridgeTask task) async => 'Simulation complete for task ${task.id}';
  @override Future<void> cancel(String taskId) async {}
  @override Future<void> disconnect(BridgeNode node) async {}
}
