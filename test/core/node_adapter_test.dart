import 'package:flutter_test/flutter_test.dart';
import 'package:brigade_bridge/core/bridge_models.dart';
import 'package:brigade_bridge/core/node_adapter.dart';

class _FakeAdapter implements NodeAdapter {
  _FakeAdapter({this.emptyInspection = false});

  final bool emptyInspection;

  @override
  String get id => 'fake-adapter';

  @override
  Future<List<BridgeNode>> discover() async => const [
        BridgeNode(
          id: 'fake-node',
          name: 'Fake node',
          kind: NodeKind.agent,
          detail: 'test',
        ),
      ];

  @override
  Future<void> connect(BridgeNode node) async {}

  @override
  Future<String> inspect(BridgeNode node) async =>
      emptyInspection ? '' : 'Fake node is ready';

  @override
  Future<String> execute(BridgeTask task) async => 'not used by self-test';

  @override
  Future<String?> readOutput(BridgeTask task) async => null;

  @override
  Future<void> waitForCompletion(BridgeTask task) async {}

  @override
  Future<void> cancel(String taskId) async {}

  @override
  Future<void> disconnect(BridgeNode node) async {}
}

void main() {
  test('adapter self-test exercises only the read-only lifecycle', () async {
    final result = await runAdapterSelfTest(_FakeAdapter());

    expect(result.passed, isTrue);
    expect(result.adapterId, 'fake-adapter');
    expect(result.checkedNodes, 1);
    expect(
        result.checks,
        containsAll(<String>[
          'discover',
          'connect:fake-node',
          'inspect:fake-node',
          'disconnect:fake-node',
        ]));
  });

  test('adapter self-test fails closed when identity inspection is empty',
      () async {
    final result =
        await runAdapterSelfTest(_FakeAdapter(emptyInspection: true));

    expect(result.passed, isFalse);
    expect(result.message, contains('Inspection returned no identity data'));
  });
}
