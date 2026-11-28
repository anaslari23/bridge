import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brigade_bridge/ui/expanded_editor.dart';
import 'package:brigade_bridge/core/bridge_models.dart';

void main() {
  final nodes = [
    const BridgeNode(
        id: 'codex', name: 'Codex', kind: NodeKind.agent, detail: 'Tab 2'),
    const BridgeNode(
        id: 'claude', name: 'Claude', kind: NodeKind.agent, detail: 'Tab 4'),
  ];
  final edges = [const NodeEdge('codex', 'claude')];

  testWidgets('renders sidebar and canvas sections', (tester) async {
    tester.view
      ..physicalSize = const Size(1200, 800)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: ExpandedEditor(
        nodes: nodes,
        edges: edges,
        tasks: const [],
        onAddEdge: (_, __) {},
        onRun: () {},
        onStop: () {},
        onCompact: () {},
        onDispatch: (_) {},
        onApprove: (_) {},
        onDeny: (_) {},
        logEntries: const [],
        status: TaskStatus.created,
      ),
    ));
    expect(find.text('WORKFLOW'), findsOneWidget);
    expect(find.text('CANVAS / DRAFT'), findsOneWidget);
    expect(find.text('ACTIVITY'), findsOneWidget);
  });

  testWidgets('settings do not offer system-wide app or project access',
      (tester) async {
    tester.view
      ..physicalSize = const Size(1800, 1200)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: ExpandedEditor(
        nodes: nodes,
        edges: edges,
        tasks: const [],
        onAddEdge: (_, __) {},
        onRun: () {},
        onStop: () {},
        onCompact: () {},
        onDispatch: (_) {},
        onApprove: (_) {},
        onDeny: (_) {},
        logEntries: const [],
        status: TaskStatus.created,
      ),
    ));

    await tester.tap(find.byTooltip('Overlay settings'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('macOS Accessibility'), findsNothing);
    expect(find.text('Screen Recording'), findsNothing);
    expect(find.text('Terminal working directory'), findsNothing);
  });

  testWidgets('connects only the OpenCode session entered by the user',
      (tester) async {
    tester.view
      ..physicalSize = const Size(1800, 1200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? connectedUrl;
    String? connectedSession;
    await tester.pumpWidget(MaterialApp(
      home: ExpandedEditor(
        nodes: nodes,
        edges: edges,
        tasks: const [],
        onAddEdge: (_, __) {},
        onRun: () {},
        onStop: () {},
        onCompact: () {},
        onDispatch: (_) {},
        onApprove: (_) {},
        onDeny: (_) {},
        onConnectOpenCode: (url, sessionId) {
          connectedUrl = url;
          connectedSession = sessionId;
        },
        logEntries: const [],
        status: TaskStatus.created,
      ),
    ));

    await tester.tap(find.byTooltip('Overlay settings'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(_connectIn('OpenCode session'));
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(find.byKey(const ValueKey('opencode-server-url')),
        'http://127.0.0.1:4096');
    await tester.enterText(
        find.byKey(const ValueKey('opencode-session-id')), 'ses_chosen');
    await tester.tap(find.text('Connect OpenCode'));
    await tester.pump(const Duration(seconds: 1));

    expect(connectedUrl, 'http://127.0.0.1:4096');
    expect(connectedSession, 'ses_chosen');
  });

  testWidgets('rejects non-loopback OpenCode server URLs in the pairing form',
      (tester) async {
    tester.view
      ..physicalSize = const Size(1800, 1200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var connectCalled = false;
    await tester.pumpWidget(MaterialApp(
      home: ExpandedEditor(
        nodes: nodes,
        edges: edges,
        tasks: const [],
        onAddEdge: (_, __) {},
        onRun: () {},
        onStop: () {},
        onCompact: () {},
        onDispatch: (_) {},
        onApprove: (_) {},
        onDeny: (_) {},
        onConnectOpenCode: (_, __) => connectCalled = true,
        logEntries: const [],
        status: TaskStatus.created,
      ),
    ));

    await tester.tap(find.byTooltip('Overlay settings'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(_connectIn('OpenCode session'));
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(find.byKey(const ValueKey('opencode-server-url')),
        'http://example.com:4096');
    await tester.enterText(
        find.byKey(const ValueKey('opencode-session-id')), 'ses_chosen');
    await tester.tap(find.text('Connect OpenCode'));
    await tester.pump(const Duration(seconds: 1));

    expect(
        find.text('OpenCode server must be on this computer'), findsOneWidget);
    expect(connectCalled, isFalse);
  });

  testWidgets('shows a disconnect action for the paired OpenCode session',
      (tester) async {
    tester.view
      ..physicalSize = const Size(1800, 1200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? disconnected;
    final openCode = const BridgeNode(
      id: 'opencode:ses_chosen',
      name: 'OpenCode',
      kind: NodeKind.agent,
      detail: 'ses_chosen at 127.0.0.1:4096',
      adapterId: 'opencode-http',
      health: 'unavailable',
    );
    await tester.pumpWidget(MaterialApp(
      home: ExpandedEditor(
        nodes: [...nodes, openCode],
        edges: edges,
        tasks: const [],
        onAddEdge: (_, __) {},
        onRun: () {},
        onStop: () {},
        onCompact: () {},
        onDispatch: (_) {},
        onApprove: (_) {},
        onDeny: (_) {},
        onDisconnectOpenCode: (id) => disconnected = id,
        logEntries: const [],
        status: TaskStatus.created,
      ),
    ));

    await tester.tap(find.byTooltip('Overlay settings'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('ses_chosen at 127.0.0.1:4096'), findsNWidgets(2));
    await tester.tap(find.text('Disconnect'));
    expect(disconnected, 'opencode:ses_chosen');
  });

  testWidgets('shows retry action for a paused workflow', (tester) async {
    tester.view
      ..physicalSize = const Size(1200, 800)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var retryCount = 0;
    await tester.pumpWidget(MaterialApp(
      home: ExpandedEditor(
        nodes: nodes,
        edges: edges,
        tasks: const [],
        onAddEdge: (_, __) {},
        onRun: () {},
        onStop: () {},
        onCompact: () {},
        onDispatch: (_) {},
        onApprove: (_) {},
        onDeny: (_) {},
        onRetry: () => retryCount++,
        logEntries: const [],
        status: TaskStatus.paused,
      ),
    ));

    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retryCount, 1);
  });

  testWidgets('shows cancel action while a workflow is running',
      (tester) async {
    tester.view
      ..physicalSize = const Size(1200, 800)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var cancelCount = 0;
    await tester.pumpWidget(MaterialApp(
      home: ExpandedEditor(
        nodes: nodes,
        edges: edges,
        tasks: const [],
        onAddEdge: (_, __) {},
        onRun: () {},
        onStop: () {},
        onCompact: () {},
        onDispatch: (_) {},
        onApprove: (_) {},
        onDeny: (_) {},
        onCancel: () => cancelCount++,
        logEntries: const [],
        status: TaskStatus.working,
      ),
    ));

    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    expect(cancelCount, 1);
  });

  testWidgets('renders per-task route and lifecycle state', (tester) async {
    tester.view
      ..physicalSize = const Size(1200, 800)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final task = BridgeTask(
      id: 'task-1',
      sourceNodeId: 'codex',
      targetNodeId: 'claude',
      instruction: 'Summarize the research',
    )
      ..status = TaskStatus.completed
      ..result = 'Done';
    await tester.pumpWidget(MaterialApp(
      home: ExpandedEditor(
        nodes: nodes,
        edges: edges,
        tasks: [task],
        onAddEdge: (_, __) {},
        onRun: () {},
        onStop: () {},
        onCompact: () {},
        onDispatch: (_) {},
        onApprove: (_) {},
        onDeny: (_) {},
        logEntries: const [],
        status: TaskStatus.completed,
      ),
    ));

    expect(find.text('TASKS'), findsOneWidget);
    expect(find.text('Codex  →  Claude'), findsNWidgets(2));
    expect(find.text('DONE'), findsNWidgets(2));
    expect(find.text('Summarize the research'), findsOneWidget);
  });

  testWidgets('loads a failed task into the composer for manual takeover',
      (tester) async {
    tester.view
      ..physicalSize = const Size(1200, 800)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final task = BridgeTask(
      id: 'failed-task',
      sourceNodeId: 'codex',
      targetNodeId: 'claude',
      instruction: 'Review the failed run',
    )
      ..status = TaskStatus.failed
      ..error = 'The tab closed';
    await tester.pumpWidget(MaterialApp(
      home: ExpandedEditor(
        nodes: nodes,
        edges: edges,
        tasks: [task],
        onAddEdge: (_, __) {},
        onRun: () {},
        onStop: () {},
        onCompact: () {},
        onDispatch: (_) {},
        onDeny: (_) {},
        onApprove: (_) {},
        onDispatchWithContext: (_, __, ___, ____, _____) {},
        logEntries: const [],
        status: TaskStatus.failed,
      ),
    ));

    await tester.tap(find.text('Take over'));
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('task-composer')))
            .controller!
            .text,
        'Review the failed run');
  });

  testWidgets('selects an active project and per-command lead override',
      (tester) async {
    tester.view
      ..physicalSize = const Size(1800, 1100)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final connected = [
      const BridgeNode(
        id: 'claude',
        name: 'Claude',
        kind: NodeKind.browser,
        detail: '',
        capabilities: ['receive_task'],
        health: 'connected',
      ),
      const BridgeNode(
        id: 'codex',
        name: 'Codex',
        kind: NodeKind.browser,
        detail: '',
        capabilities: ['receive_task'],
        health: 'connected',
      ),
    ];
    String? selectedProject;
    String? dispatchedTarget;
    await tester.pumpWidget(MaterialApp(
      home: ExpandedEditor(
        nodes: connected,
        edges: const [],
        tasks: const [],
        projects: const [
          ProjectContext(id: 'project-a', name: 'Alpha'),
          ProjectContext(id: 'project-b', name: 'Beta'),
        ],
        activeProjectId: 'project-a',
        onSelectProject: (id) => selectedProject = id,
        onCreateProject: (_) {},
        onAddEdge: (_, __) {},
        onRun: () {},
        onStop: () {},
        onCompact: () {},
        onDispatch: (_) {},
        onDispatchWithContext: (text, source, target, attachments, contexts) {
          dispatchedTarget = target;
        },
        onApprove: (_) {},
        onDeny: (_) {},
        logEntries: const [],
        status: TaskStatus.created,
      ),
    ));

    await tester.tap(find.byKey(const ValueKey('active-project-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beta').last);
    await tester.pumpAndSettle();
    expect(selectedProject, 'project-b');

    await tester.tap(find.descendant(
      of: find.byKey(const ValueKey('lead-selector')),
      matching: find.byType(DropdownButton<String>),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Codex').last);
    await tester.enterText(
        find.byKey(const ValueKey('task-composer')), 'Fix parser');
    await tester.tap(find.text('Dispatch task'));
    expect(dispatchedTarget, 'codex');
  });

  testWidgets('renders delegated task parent and depth', (tester) async {
    tester.view
      ..physicalSize = const Size(1800, 1100)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final child = BridgeTask(
      id: 'child-1',
      sourceNodeId: 'claude',
      targetNodeId: 'codex',
      instruction: 'Review the parser',
      parentTaskId: 'parent-1',
      handoffDepth: 1,
    )
      ..status = TaskStatus.completed
      ..result = 'Parser review complete';
    await tester.pumpWidget(MaterialApp(
      home: ExpandedEditor(
        nodes: nodes,
        edges: const [],
        tasks: [child],
        onAddEdge: (_, __) {},
        onRun: () {},
        onStop: () {},
        onCompact: () {},
        onDispatch: (_) {},
        onApprove: (_) {},
        onDeny: (_) {},
        logEntries: const [],
        status: TaskStatus.completed,
      ),
    ));
    expect(find.textContaining('Delegated · depth 1'), findsOneWidget);
    expect(find.text('Review the parser'), findsOneWidget);
    expect(find.text('Parser review complete'), findsOneWidget);
  });

  testWidgets('creates a named project context', (tester) async {
    tester.view
      ..physicalSize = const Size(1800, 1100)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? createdName;
    await tester.pumpWidget(MaterialApp(
      home: ExpandedEditor(
        nodes: const [],
        edges: const [],
        tasks: const [],
        projects: const [],
        activeProjectId: '',
        onCreateProject: (name) => createdName = name,
        onAddEdge: (_, __) {},
        onRun: () {},
        onStop: () {},
        onCompact: () {},
        onDispatch: (_) {},
        onApprove: (_) {},
        onDeny: (_) {},
        logEntries: const [],
        status: TaskStatus.created,
      ),
    ));
    await tester.tap(find.byTooltip('Create project context'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Release notes');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(createdName, 'Release notes');
  });

  testWidgets('connects Codex, Antigravity and Claude Code from settings',
      (tester) async {
    tester.view
      ..physicalSize = const Size(1800, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final calls = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: ExpandedEditor(
        nodes: nodes,
        edges: edges,
        tasks: const [],
        onAddEdge: (_, __) {},
        onRun: () {},
        onStop: () {},
        onCompact: () {},
        onDispatch: (_) {},
        onApprove: (_) {},
        onDeny: (_) {},
        onConnectCodex: (url, id) => calls.add('codex $url $id'),
        onConnectAntigravity: (dir, id) => calls.add('agy $dir ${id ?? '-'}'),
        onConnectClaudeCode: (dir, id) => calls.add('claude $dir ${id ?? '-'}'),
        logEntries: const [],
        status: TaskStatus.created,
      ),
    ));
    await tester.tap(find.byTooltip('Overlay settings'));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(_connectIn('Codex thread'));
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(
        find.byKey(const ValueKey('codex-thread-id')), 'thr_1');
    await tester.tap(_submit('Connect Codex'));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(_connectIn('Antigravity (CLI)'));
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(
        find.byKey(const ValueKey('antigravity-working-directory')), '/tmp');
    await tester.tap(_submit('Connect Antigravity'));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(_connectIn('Claude Code (CLI)'));
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(
        find.byKey(const ValueKey('claude-code-working-directory')), '/tmp');
    await tester.enterText(
        find.byKey(const ValueKey('claude-code-session-id')), 'sess-1');
    await tester.tap(_submit('Connect Claude Code'));
    await tester.pump(const Duration(seconds: 1));

    expect(calls, [
      'codex ws://127.0.0.1:4500 thr_1',
      'agy /tmp -',
      'claude /tmp sess-1',
    ]);
  });

  testWidgets('rejects invalid connector input without connecting',
      (tester) async {
    tester.view
      ..physicalSize = const Size(1800, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var called = false;
    await tester.pumpWidget(MaterialApp(
      home: ExpandedEditor(
        nodes: nodes,
        edges: edges,
        tasks: const [],
        onAddEdge: (_, __) {},
        onRun: () {},
        onStop: () {},
        onCompact: () {},
        onDispatch: (_) {},
        onApprove: (_) {},
        onDeny: (_) {},
        onConnectCodex: (_, __) => called = true,
        onConnectClaudeCode: (_, __) => called = true,
        logEntries: const [],
        status: TaskStatus.created,
      ),
    ));
    await tester.tap(find.byTooltip('Overlay settings'));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(_connectIn('Codex thread'));
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(find.byKey(const ValueKey('codex-server-url')),
        'ws://example.com:4500');
    await tester.enterText(
        find.byKey(const ValueKey('codex-thread-id')), 'thr_1');
    await tester.tap(_submit('Connect Codex'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Codex server must be on this computer'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(_connectIn('Claude Code (CLI)'));
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(
        find.byKey(const ValueKey('claude-code-working-directory')),
        'relative/dir');
    await tester.tap(_submit('Connect Claude Code'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Enter an absolute working directory'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets(
      'settings dialog scrolls instead of overflowing in a short window',
      (tester) async {
    tester.view
      ..physicalSize = const Size(900, 520)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: ExpandedEditor(
        nodes: nodes,
        edges: edges,
        tasks: const [],
        onAddEdge: (_, __) {},
        onRun: () {},
        onStop: () {},
        onCompact: () {},
        onDispatch: (_) {},
        onApprove: (_) {},
        onDeny: (_) {},
        onConnectOpenCode: (_, __) {},
        onConnectCodex: (_, __) {},
        onConnectAntigravity: (_, __) {},
        onConnectClaudeCode: (_, __) {},
        logEntries: const [],
        status: TaskStatus.created,
      ),
    ));
    await tester.tap(find.byTooltip('Overlay settings'));
    await tester.pump(const Duration(seconds: 1));

    // No RenderFlex overflow was reported while laying the dialog out.
    expect(tester.takeException(), isNull);
    // The last row is reachable by scrolling.
    await tester.scrollUntilVisible(
        find.text('Local Chrome pairing token'), 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Local Chrome pairing token'), findsOneWidget);
  });

  testWidgets('shows a disconnect action for each paired CLI connector',
      (tester) async {
    tester.view
      ..physicalSize = const Size(1800, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final disconnected = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: ExpandedEditor(
        nodes: [
          ...nodes,
          const BridgeNode(
              id: 'codex:thr_1',
              name: 'Codex',
              kind: NodeKind.agent,
              detail: 'thr_1 at 127.0.0.1:4500',
              adapterId: 'codex-app-server'),
          const BridgeNode(
              id: 'antigravity:new',
              name: 'Antigravity',
              kind: NodeKind.agent,
              detail: 'new conversation in /tmp',
              adapterId: 'antigravity-cli'),
          const BridgeNode(
              id: 'claude-code:new',
              name: 'Claude Code',
              kind: NodeKind.agent,
              detail: 'new session in /tmp',
              adapterId: 'claude-code-cli'),
        ],
        edges: edges,
        tasks: const [],
        onAddEdge: (_, __) {},
        onRun: () {},
        onStop: () {},
        onCompact: () {},
        onDispatch: (_) {},
        onApprove: (_) {},
        onDeny: (_) {},
        onDisconnectCodex: disconnected.add,
        onDisconnectAntigravity: disconnected.add,
        onDisconnectClaudeCode: disconnected.add,
        logEntries: const [],
        status: TaskStatus.created,
      ),
    ));
    await tester.tap(find.byTooltip('Overlay settings'));
    await tester.pump(const Duration(seconds: 1));

    for (final title in [
      'Codex thread',
      'Antigravity (CLI)',
      'Claude Code (CLI)'
    ]) {
      await tester.tap(find.descendant(
          of: find.widgetWithText(ListTile, title),
          matching: find.text('Disconnect')));
      await tester.pump();
    }
    expect(disconnected, ['codex:thr_1', 'antigravity:new', 'claude-code:new']);
  });

  group('layout', () {
    Widget editor(List<BridgeNode> nodeList) => MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ExpandedEditor(
            nodes: nodeList,
            edges: const [],
            tasks: const [],
            onAddEdge: (_, __) {},
            onRun: () {},
            onStop: () {},
            onCompact: () {},
            onDispatch: (_) {},
            onApprove: (_) {},
            onDeny: (_) {},
            logEntries: const [],
            status: TaskStatus.created,
          ),
        );

    final threeNodes = [
      ...nodes,
      const BridgeNode(
          id: 'claude-code:new',
          name: 'Claude Code',
          kind: NodeKind.agent,
          detail: 'new session in /home/me/app'),
    ];

    for (final size in const [
      Size(700, 500),
      Size(800, 600),
      Size(1000, 700),
      Size(1099, 700),
      Size(1100, 700),
      Size(1440, 900),
    ]) {
      testWidgets(
          'has no overflow and keeps Run reachable at '
          '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        tester.view
          ..physicalSize = size
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(editor(threeNodes));
        await tester.pump(const Duration(seconds: 1));

        expect(tester.takeException(), isNull);
        // Run is a labelled button when wide and an icon button when narrow.
        expect(
          find.text('Run workflow').evaluate().length +
              find.byTooltip('Run workflow').evaluate().length,
          1,
        );
      });
    }

    testWidgets('default node placement leaves a gap between cards',
        (tester) async {
      tester.view
        ..physicalSize = const Size(800, 600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(editor(threeNodes));
      await tester.pump(const Duration(seconds: 1));

      // Cards are 180x150. Each pair must be separated by at least a card
      // size horizontally or vertically (i.e. they do not overlap).
      final origins = [
        for (final name in ['Codex', 'Claude', 'Claude Code'])
          tester.getTopLeft(find.text(name).last),
      ];
      for (var i = 0; i < origins.length; i++) {
        for (var j = i + 1; j < origins.length; j++) {
          final dx = (origins[i].dx - origins[j].dx).abs();
          final dy = (origins[i].dy - origins[j].dy).abs();
          expect(dx >= 180 || dy >= 150, isTrue,
              reason: 'cards $i and $j overlap (dx=$dx, dy=$dy)');
        }
      }
    });

    testWidgets('node titles are not truncated by the header buttons',
        (tester) async {
      final root = Platform.environment['FLUTTER_ROOT'];
      final fonts = root == null
          ? null
          : Directory('$root/bin/cache/artifacts/material_fonts');
      if (fonts == null || !fonts.existsSync()) {
        markTestSkipped('Flutter SDK fonts are not available');
        return;
      }
      final loader = FontLoader('Roboto');
      for (final file in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
        loader.addFont(Future.value(ByteData.sublistView(
            File('${fonts.path}/$file').readAsBytesSync())));
      }
      await loader.load();
      // Loading fonts posts a platform message that schedules a frame; let it
      // arrive and run before the test body so it cannot outlive the test.
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();

      tester.view
        ..physicalSize = const Size(1280, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(useMaterial3: true).copyWith(
            textTheme:
                Typography.material2021().white.apply(fontFamily: 'Roboto')),
        home: ExpandedEditor(
          nodes: const [
            BridgeNode(
                id: 'claude-code:new',
                name: 'Claude Code',
                kind: NodeKind.agent,
                detail: 'new session'),
            BridgeNode(
                id: 'tab-7',
                name: 'Antigravity tab',
                kind: NodeKind.browser,
                detail: 'Tab 7'),
          ],
          edges: const [],
          tasks: const [],
          onAddEdge: (_, __) {},
          onRun: () {},
          onStop: () {},
          onCompact: () {},
          onDispatch: (_) {},
          onApprove: (_) {},
          onDeny: (_) {},
          logEntries: const [],
          status: TaskStatus.created,
        ),
      ));
      await tester.pump(const Duration(seconds: 1));

      for (final name in ['Claude Code', 'Antigravity tab']) {
        final rendered = tester.getSize(find.text(name).last).width;
        final natural = (TextPainter(
          text: TextSpan(
              text: name,
              style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout())
            .width;
        expect(rendered, greaterThanOrEqualTo(natural - 1),
            reason: '"$name" is ellipsised (rendered $rendered < $natural)');
      }
    });
  });

  group('extension token dialog', () {
    const token = 'tok-abcdef-0123456789';

    Future<int> openDialog(WidgetTester tester,
        {String localToken = token, Size size = const Size(1800, 1400)}) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var copies = 0;
      await tester.pumpWidget(MaterialApp(
        home: ExpandedEditor(
          nodes: nodes,
          edges: edges,
          tasks: const [],
          onAddEdge: (_, __) {},
          onRun: () {},
          onStop: () {},
          onCompact: () {},
          onDispatch: (_) {},
          onApprove: (_) {},
          onDeny: (_) {},
          localAuthToken: localToken,
          onCopyLocalAuthToken: () => copies++,
          logEntries: const [],
          status: TaskStatus.created,
        ),
      ));
      await tester.tap(find.byTooltip('Overlay settings'));
      await tester.pump(const Duration(seconds: 1));
      final tile = find.widgetWithText(ListTile, 'Claude Desktop extension');
      await tester.scrollUntilVisible(tile, 200,
          scrollable: find.byType(Scrollable).last);
      await tester
          .tap(find.descendant(of: tile, matching: find.text('Set up')));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 400));
      return copies;
    }

    String fieldText(WidgetTester tester, String key) {
      final widget = tester.widget(find.byKey(ValueKey(key)));
      if (widget is Text) return widget.data!;
      if (widget is SelectableText) return widget.data!;
      throw StateError('unexpected widget $widget');
    }

    testWidgets('hides the token until revealed, and can hide it again',
        (tester) async {
      await openDialog(tester);
      expect(
          fieldText(tester, 'extension-token-field'), isNot(contains('tok')));
      expect(fieldText(tester, 'extension-token-field'), '•' * 24);

      await tester.tap(find.byKey(const ValueKey('extension-token-reveal')));
      await tester.pump();
      expect(fieldText(tester, 'extension-token-field'), token);

      await tester.tap(find.byKey(const ValueKey('extension-token-reveal')));
      await tester.pump();
      expect(fieldText(tester, 'extension-token-field'), '•' * 24);
    });

    testWidgets(
        'copies the token through the app callback without revealing it',
        (tester) async {
      var copies = 0;
      tester.view
        ..physicalSize = const Size(1800, 1400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: ExpandedEditor(
          nodes: nodes,
          edges: edges,
          tasks: const [],
          onAddEdge: (_, __) {},
          onRun: () {},
          onStop: () {},
          onCompact: () {},
          onDispatch: (_) {},
          onApprove: (_) {},
          onDeny: (_) {},
          localAuthToken: token,
          onCopyLocalAuthToken: () => copies++,
          logEntries: const [],
          status: TaskStatus.created,
        ),
      ));
      await tester.tap(find.byTooltip('Overlay settings'));
      await tester.pump(const Duration(seconds: 1));
      final tile = find.widgetWithText(ListTile, 'Claude Desktop extension');
      await tester.scrollUntilVisible(tile, 200,
          scrollable: find.byType(Scrollable).last);
      await tester
          .tap(find.descendant(of: tile, matching: find.text('Set up')));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byKey(const ValueKey('extension-token-copy')));
      await tester.pump();
      expect(copies, 1);
      expect(find.text('Token copied to the clipboard'), findsOneWidget);
      expect(fieldText(tester, 'extension-token-field'), '•' * 24);
    });

    testWidgets('shows the daemon address and copies it to the clipboard',
        (tester) async {
      final clipboard = <String?>[];
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard.add((call.arguments as Map)['text'] as String?);
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      await openDialog(tester);

      expect(
          fieldText(tester, 'extension-address-field'), 'ws://127.0.0.1:7432');
      await tester.tap(find.byKey(const ValueKey('extension-address-copy')));
      await tester.pump();
      expect(clipboard, ['ws://127.0.0.1:7432']);
      expect(find.text('Address copied to the clipboard'), findsOneWidget);
    });

    testWidgets('disables reveal and copy while the daemon is still starting',
        (tester) async {
      await openDialog(tester, localToken: '');
      expect(
          fieldText(tester, 'extension-token-field'), 'Starting local daemon…');
      expect(
          tester
              .widget<IconButton>(
                  find.byKey(const ValueKey('extension-token-reveal')))
              .onPressed,
          isNull);
      expect(
          tester
              .widget<IconButton>(
                  find.byKey(const ValueKey('extension-token-copy')))
              .onPressed,
          isNull);
    });

    testWidgets('fits a small window and can be closed', (tester) async {
      await openDialog(tester, size: const Size(800, 600));
      expect(tester.takeException(), isNull);

      // Two dialogs are open (settings, then this one), each with its own
      // Done button; use the one inside the extension dialog.
      final dialog = find.ancestor(
          of: find.byKey(const ValueKey('extension-token-field')),
          matching: find.byType(AlertDialog));
      final done = find.descendant(of: dialog, matching: find.text('Done'));
      expect(done, findsOneWidget);
      await tester.tap(done);
      // The first frame only starts the closing animation; the second ends it.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('extension-token-field')), findsNothing);
      // The settings dialog underneath is still open.
      expect(find.text('Overlay settings'), findsOneWidget);
    });
  });
}

Finder _connectIn(String tileTitle) => find.descendant(
    of: find.widgetWithText(ListTile, tileTitle),
    matching: find.text('Connect'));

Finder _submit(String label) => find.widgetWithText(FilledButton, label);
