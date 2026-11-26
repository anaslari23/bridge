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
    await tester.tap(find.text('Connect'));
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
    await tester.tap(find.text('Connect'));
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
}
