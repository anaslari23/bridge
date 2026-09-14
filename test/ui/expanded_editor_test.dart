import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brigade_bridge/ui/expanded_editor.dart';
import 'package:brigade_bridge/core/bridge_models.dart';

void main() {
  final nodes = [
    const BridgeNode(id: 'codex', name: 'Codex', kind: NodeKind.agent, detail: 'Tab 2'),
    const BridgeNode(id: 'claude', name: 'Claude', kind: NodeKind.agent, detail: 'Tab 4'),
  ];
  final edges = [const NodeEdge('codex', 'claude')];

  testWidgets('renders sidebar and canvas sections', (tester) async {
    tester.view
      ..physicalSize = const Size(1200, 800)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: ExpandedEditor(
        nodes: nodes, edges: edges, tasks: const [],
        onAddEdge: (_, __) {}, onRun: () {}, onStop: () {},
        onCompact: () {}, onDispatch: (_) {}, onApprove: (_) {}, onDeny: (_) {},
        logEntries: const [], status: TaskStatus.created,
      ),
    ));
    expect(find.text('WORKFLOW'), findsOneWidget);
    expect(find.text('CANVAS / DRAFT'), findsOneWidget);
    expect(find.text('ACTIVITY'), findsOneWidget);
  });
}
