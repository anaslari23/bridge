// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brigade_bridge/main.dart';

void main() {
  testWidgets('renders the Brigade Bridge workspace', (WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1800, 1200)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const BridgeApp());
    expect(find.text('Brigade Bridge'), findsOneWidget);
    expect(find.text('Expand'), findsOneWidget);

    await tester.tap(find.text('Expand'));
    await tester.pumpAndSettle();
    expect(find.text('Workspaces'), findsOneWidget);
    expect(find.text('CANVAS / DRAFT'), findsOneWidget);
  });
}
