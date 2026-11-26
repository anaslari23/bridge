import 'bridge_models.dart';

class AdapterDispatchException implements Exception {
  AdapterDispatchException(this.message, {this.retryable = false});
  final String message;
  final bool retryable;

  @override
  String toString() => message;
}

/// Contract implemented by local integrations. Adapters use the user's
/// existing application session; they never receive or extract API keys.
abstract interface class NodeAdapter {
  String get id;
  Future<List<BridgeNode>> discover();
  Future<void> connect(BridgeNode node);
  Future<String> inspect(BridgeNode node);
  Future<String> execute(BridgeTask task);
  Future<String?> readOutput(BridgeTask task);
  Future<void> waitForCompletion(BridgeTask task);
  Future<void> cancel(String taskId);
  Future<void> disconnect(BridgeNode node);
}

class AdapterSelfTestResult {
  const AdapterSelfTestResult({
    required this.adapterId,
    required this.passed,
    required this.checkedNodes,
    required this.checks,
    required this.message,
  });

  final String adapterId;
  final bool passed;
  final int checkedNodes;
  final List<String> checks;
  final String message;
}

/// Exercises only discovery and read-only lifecycle methods. It never calls
/// [NodeAdapter.execute], so running a self-test cannot send text, click, run
/// commands, or mutate a user's files.
Future<AdapterSelfTestResult> runAdapterSelfTest(NodeAdapter adapter) async {
  final checks = <String>[];
  try {
    final nodes = await adapter.discover();
    checks.add('discover');
    for (final node in nodes) {
      await adapter.connect(node);
      checks.add('connect:${node.id}');
      final inspection = await adapter.inspect(node);
      if (inspection.trim().isEmpty) {
        throw StateError('Inspection returned no identity data for ${node.id}');
      }
      checks.add('inspect:${node.id}');
      await adapter.disconnect(node);
      checks.add('disconnect:${node.id}');
    }
    return AdapterSelfTestResult(
      adapterId: adapter.id,
      passed: true,
      checkedNodes: nodes.length,
      checks: checks,
      message: nodes.isEmpty
          ? 'Discovery succeeded; no nodes are currently available'
          : 'Discovery and read-only lifecycle succeeded',
    );
  } catch (error) {
    return AdapterSelfTestResult(
      adapterId: adapter.id,
      passed: false,
      checkedNodes: 0,
      checks: checks,
      message: error.toString(),
    );
  }
}

class LocalSimulationAdapter implements NodeAdapter {
  @override
  String get id => 'local-simulation';
  @override
  Future<List<BridgeNode>> discover() async => const [];
  @override
  Future<void> connect(BridgeNode node) async {}
  @override
  Future<String> inspect(BridgeNode node) async =>
      'Local node ready: ${node.name}';
  @override
  Future<String> execute(BridgeTask task) async =>
      'Simulation complete for task ${task.id}';
  @override
  Future<String?> readOutput(BridgeTask task) async => null;
  @override
  Future<void> waitForCompletion(BridgeTask task) async {}
  @override
  Future<void> cancel(String taskId) async {}
  @override
  Future<void> disconnect(BridgeNode node) async {}
}
