import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brigade_bridge/ui/compact_hud.dart';
import 'package:brigade_bridge/core/bridge_models.dart';

void main() {
  final testNodes = [
    const BridgeNode(id: 'n1', name: 'Codex', kind: NodeKind.agent, detail: 'Chrome · Tab 2'),
    const BridgeNode(id: 'n2', name: 'Claude', kind: NodeKind.agent, detail: 'Chrome · Tab 4'),
  ];

  testWidgets('shows node chips for each node', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CompactHud(
        nodes: testNodes,
        onExpand: () {},
        onRun: () {},
        onStop: () {},
        logTail: 'Bridge online',
        status: TaskStatus.created,
      ),
    ));
    expect(find.text('Codex'), findsOneWidget);
    expect(find.text('Claude'), findsOneWidget);
  });

  testWidgets('run button triggers onRun callback', (tester) async {
    bool ran = false;
    await tester.pumpWidget(MaterialApp(
      home: CompactHud(
        nodes: testNodes,
        onExpand: () {},
        onRun: () => ran = true,
        onStop: () {},
        logTail: '',
        status: TaskStatus.created,
      ),
    ));
    await tester.tap(find.widgetWithText(FilledButton, 'Run'));
    expect(ran, isTrue);
  });
}
