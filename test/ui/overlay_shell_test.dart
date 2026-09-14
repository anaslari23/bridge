import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brigade_bridge/ui/overlay_shell.dart';
import 'package:brigade_bridge/core/bridge_models.dart';

void main() {
  testWidgets('starts in compact mode', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: OverlayShell(
        nodes: const [],
        edges: const [],
        tasks: const [],
        logEntries: const [],
        onRun: () {},
        onStop: () {},
        onAddEdge: (_, __) {},
        onDispatch: (_) {},
        onApprove: (_) {},
        onDeny: (_) {},
        status: TaskStatus.created,
        logTail: '',
      ),
    ));
    expect(find.text('Expand'), findsOneWidget);
    expect(find.text('CANVAS / DRAFT'), findsNothing);
  });

  testWidgets('expand button switches to expanded mode', (tester) async {
    tester.view
      ..physicalSize = const Size(1200, 800)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: OverlayShell(
        nodes: const [],
        edges: const [],
        tasks: const [],
        logEntries: const [],
        onRun: () {},
        onStop: () {},
        onAddEdge: (_, __) {},
        onDispatch: (_) {},
        onApprove: (_) {},
        onDeny: (_) {},
        status: TaskStatus.created,
        logTail: '',
      ),
    ));
    await tester.tap(find.text('Expand'));
    await tester.pump();
    expect(find.text('CANVAS / DRAFT'), findsOneWidget);
  });
}
