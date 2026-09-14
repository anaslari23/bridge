# Brigade Bridge — Milestone 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the first working end-to-end milestone: ⌥Space shows the overlay, three agent tabs appear as nodes, the user draws edges, dispatches a task, approves it, the daemon sends it through the existing Chrome sessions, reads the responses, and hides the overlay without killing the daemon.

**Architecture:** Flutter macOS NSPanel overlay (compact HUD ↔ expanded editor) → Dart Isolate daemon (WebSocket on localhost:7432, SQLite via drift) → Chrome MV3 extension (service worker + content scripts + per-adapter state machines). Each layer is built and tested independently before the next layer connects to it.

**Tech Stack:** Flutter 3.x (macOS), Dart 3.x, Swift (method channel), drift 2.x, web_socket_channel 3.x, hotkey_manager 0.2.x, uuid 4.x, Chrome Manifest V3

**Spec:** `docs/superpowers/specs/2026-09-14-brigade-bridge-design.md`

## Global Constraints

- Minimum macOS: 13 Ventura (SMAppService API)
- Flutter channel: stable
- Dart SDK: >=3.0.0 <4.0.0
- All Dart packages must have macOS support confirmed on pub.dev
- LSUIElement = YES must be set before any window appears (Info.plist, not runtime)
- No remote network calls; all communication is localhost only
- All nodes start at permission tier read_only; no capability above read_only runs without an explicit approval event
- Emergency stop must propagate within one event-loop tick across every active task
- Never read or write document.cookie, localStorage, or sessionStorage in any content script
- SQLite DB path: ~/Library/Application Support/BrigadeBridge/brigade.db
- Artifact path: ~/Library/Application Support/BrigadeBridge/artifacts/{task_id}/

---

## Phase 1 — macOS Overlay Shell

### Task 1: Project bootstrap + pubspec dependencies

**Files:**
- Modify: `pubspec.yaml`
- Modify: `macos/Runner/Info.plist`
- Modify: `macos/Runner/AppDelegate.swift`
- Modify: `macos/Runner/MainFlutterWindow.swift`

**Interfaces:**
- Produces: Flutter app launches with no Dock icon; window is NSPanel; dependencies available to all subsequent tasks

- [ ] **Step 1: Add dependencies to pubspec.yaml**

```yaml
dependencies:
  flutter:
    sdk: flutter
  hotkey_manager: ^0.2.3
  web_socket_channel: ^3.0.1
  drift: ^2.18.0
  sqlite3_flutter_libs: ^0.5.24
  uuid: ^4.4.0
  path_provider: ^2.1.3
  path: ^1.9.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  drift_dev: ^2.18.0
  build_runner: ^2.4.11
```

- [ ] **Step 2: Run pub get and verify resolution**

```bash
cd "/Users/anaslari/Downloads/brigade bridge"
flutter pub get
```
Expected: "Got dependencies!" with no version conflicts.

- [ ] **Step 3: Set LSUIElement in Info.plist**

Open `macos/Runner/Info.plist`. Add before the closing `</dict>`:
```xml
<key>LSUIElement</key>
<true/>
```

This hides the app from the Dock and App Switcher. Must be set before any window appears.

- [ ] **Step 4: Replace MainFlutterWindow with NSPanel**

Replace entire contents of `macos/Runner/MainFlutterWindow.swift`:
```swift
import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSPanel {

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Overlay behaviour
    self.level = .floating
    self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    self.isMovableByWindowBackground = true
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    self.backgroundColor = NSColor.clear
    self.isOpaque = false
    self.hasShadow = true

    // Panel-specific: don't steal focus
    self.becomesKeyOnlyIfNeeded = true

    RegisterGeneratedPlugins(registry: flutterViewController)
    super.awakeFromNib()
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}
```

- [ ] **Step 5: Update AppDelegate to not activate the app on launch**

Replace contents of `macos/Runner/AppDelegate.swift`:
```swift
import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    return true
  }

  override func applicationShouldTerminateAfterLastWindowClosed(
    _ application: NSApplication
  ) -> Bool {
    return false   // daemon keeps running when overlay is hidden
  }
}
```

- [ ] **Step 6: Build and verify**

```bash
cd "/Users/anaslari/Downloads/brigade bridge"
flutter build macos --debug
open build/macos/Build/Products/Debug/brigade_bridge.app
```
Expected: App launches, no Dock icon appears, transparent window visible.

- [ ] **Step 7: Commit**

```bash
cd "/Users/anaslari/Downloads/brigade bridge"
git add pubspec.yaml pubspec.lock macos/Runner/Info.plist \
        macos/Runner/AppDelegate.swift macos/Runner/MainFlutterWindow.swift
git commit -m "feat: bootstrap NSPanel overlay shell, LSUIElement, pubspec deps"
```

---

### Task 2: BridgeChannel — Swift method channel

**Files:**
- Create: `macos/Runner/BridgeChannel.swift`
- Modify: `macos/Runner/AppDelegate.swift`
- Create: `lib/platform/bridge_channel.dart`

**Interfaces:**
- Produces:
  - Swift: `BridgeChannel.register(with:)` — call from AppDelegate
  - Dart: `BridgeChannel` class with `showPanel()`, `hidePanel()`, `setStatusBadge(String)`, `registerHotKey()`, `onHotKeyFired` Stream

- [ ] **Step 1: Create BridgeChannel.swift**

Create `macos/Runner/BridgeChannel.swift`:
```swift
import Cocoa
import FlutterMacOS

class BridgeChannel {
  static let name = "com.brigade.bridge/channel"
  private var statusItem: NSStatusItem?
  private var channel: FlutterMethodChannel?

  func register(with registrar: FlutterPluginRegistrar) {
    channel = FlutterMethodChannel(
      name: BridgeChannel.name,
      binaryMessenger: registrar.messenger
    )
    channel?.setMethodCallHandler(handle)
    setupStatusItem(registrar: registrar)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "showPanel":
      NSApp.windows.first?.makeKeyAndOrderFront(nil)
      result(nil)
    case "hidePanel":
      NSApp.windows.first?.orderOut(nil)
      result(nil)
    case "setStatusBadge":
      let state = call.arguments as? String ?? "idle"
      updateBadge(state: state)
      result(nil)
    case "requestAccessibility":
      let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
      AXIsProcessTrustedWithOptions(options as CFDictionary)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func setupStatusItem(registrar: FlutterPluginRegistrar) {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let button = statusItem?.button {
      button.title = "✦"
      button.action = #selector(togglePanel)
      button.target = self
    }
  }

  @objc private func togglePanel() {
    channel?.invokeMethod("hotkey_fired", arguments: nil)
  }

  private func updateBadge(state: String) {
    guard let button = statusItem?.button else { return }
    switch state {
    case "running", "waiting":
      button.contentTintColor = NSColor.systemOrange
    case "stopped":
      button.contentTintColor = NSColor.systemRed
    default:
      button.contentTintColor = NSColor.systemGreen
    }
  }
}
```

- [ ] **Step 2: Register BridgeChannel in AppDelegate.swift**

Replace `macos/Runner/AppDelegate.swift`:
```swift
import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  let bridgeChannel = BridgeChannel()

  override func applicationDidFinishLaunching(_ notification: Notification) {
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController
    else { return }
    // FlutterPluginRegistrar shim
    let registrar = controller.registrar(forPlugin: "BridgeChannel")
    bridgeChannel.register(with: registrar)
  }

  override func applicationShouldHandleReopen(
    _ sender: NSApplication, hasVisibleWindows flag: Bool
  ) -> Bool { true }

  override func applicationShouldTerminateAfterLastWindowClosed(
    _ application: NSApplication
  ) -> Bool { false }
}
```

- [ ] **Step 3: Create lib/platform/bridge_channel.dart**

Create `lib/platform/bridge_channel.dart`:
```dart
import 'package:flutter/services.dart';

class BridgeChannel {
  static const _channel = MethodChannel('com.brigade.bridge/channel');

  static final _hotKeyController = StreamController<void>.broadcast();
  static Stream<void> get onHotKeyFired => _hotKeyController.stream;

  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'hotkey_fired') {
        _hotKeyController.add(null);
      }
    });
  }

  static Future<void> showPanel() => _channel.invokeMethod('showPanel');
  static Future<void> hidePanel() => _channel.invokeMethod('hidePanel');
  static Future<void> setStatusBadge(String state) =>
      _channel.invokeMethod('setStatusBadge', state);
  static Future<void> requestAccessibility() =>
      _channel.invokeMethod('requestAccessibility');
}
```

Add the missing import at the top of the file:
```dart
import 'dart:async';
```

- [ ] **Step 4: Wire BridgeChannel.init() in main.dart**

In `lib/main.dart` replace the `main()` function:
```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  BridgeChannel.init();
  runApp(const BridgeApp());
}
```

And add the import:
```dart
import 'platform/bridge_channel.dart';
```

- [ ] **Step 5: Build and verify status item appears**

```bash
flutter build macos --debug && \
open build/macos/Build/Products/Debug/brigade_bridge.app
```
Expected: ✦ appears in the menu bar; clicking it fires a method call (visible via `print` added temporarily to `togglePanel`).

- [ ] **Step 6: Commit**

```bash
git add macos/Runner/BridgeChannel.swift macos/Runner/AppDelegate.swift \
        lib/platform/bridge_channel.dart lib/main.dart
git commit -m "feat: BridgeChannel Swift method channel, status item"
```

---

### Task 3: Compact HUD widget

**Files:**
- Create: `lib/ui/compact_hud.dart`
- Create: `lib/ui/node_chip.dart`

**Interfaces:**
- Consumes: `BridgeNode` from `lib/core/bridge_models.dart`; `BridgeChannel.showPanel` / `hidePanel`
- Produces: `CompactHud(nodes, onExpand, onRun, onStop)` widget — the 280×420 floating panel content

- [ ] **Step 1: Write widget tests**

Create `test/ui/compact_hud_test.dart`:
```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/ui/compact_hud_test.dart
```
Expected: FAIL — `compact_hud.dart` not found.

- [ ] **Step 3: Create lib/ui/node_chip.dart**

```dart
import 'package:flutter/material.dart';
import '../core/bridge_models.dart';

class NodeChip extends StatelessWidget {
  const NodeChip({super.key, required this.node, this.isSelected = false});
  final BridgeNode node;
  final bool isSelected;

  Color get _color {
    switch (node.kind) {
      case NodeKind.agent:   return const Color(0xff7188ff);
      case NodeKind.browser: return const Color(0xffad81ff);
      case NodeKind.terminal: return const Color(0xfff2a65a);
      case NodeKind.desktop: return const Color(0xff56d19a);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xff1a1f29),
        border: Border.all(
          color: isSelected ? const Color(0xff7f95ff) : const Color(0xff2a303d),
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Container(
          width: 24, height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _color.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(node.kind == NodeKind.agent ? '✦' :
                      node.kind == NodeKind.browser ? '◈' :
                      node.kind == NodeKind.terminal ? '⌘' : '◉',
                 style: TextStyle(color: _color, fontSize: 12)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(node.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            Text(node.detail, style: const TextStyle(fontSize: 9, color: Color(0xff7d8798)),
                 overflow: TextOverflow.ellipsis),
          ],
        )),
        const Icon(Icons.circle, size: 6, color: Color(0xff56d19a)),
      ]),
    );
  }
}
```

- [ ] **Step 4: Create lib/ui/compact_hud.dart**

```dart
import 'package:flutter/material.dart';
import '../core/bridge_models.dart';
import 'node_chip.dart';

class CompactHud extends StatelessWidget {
  const CompactHud({
    super.key,
    required this.nodes,
    required this.onExpand,
    required this.onRun,
    required this.onStop,
    required this.logTail,
    required this.status,
  });

  final List<BridgeNode> nodes;
  final VoidCallback onExpand;
  final VoidCallback onRun;
  final VoidCallback onStop;
  final String logTail;
  final TaskStatus status;

  String get _statusLabel {
    switch (status) {
      case TaskStatus.working:            return 'RUNNING';
      case TaskStatus.waitingForApproval: return 'WAITING';
      case TaskStatus.completed:          return 'DONE';
      case TaskStatus.failed:             return 'FAILED';
      case TaskStatus.stopped:            return 'STOPPED';
      default:                            return 'READY';
    }
  }

  Color get _statusColor {
    switch (status) {
      case TaskStatus.working:            return const Color(0xff9fb1ff);
      case TaskStatus.waitingForApproval: return const Color(0xfff2a65a);
      case TaskStatus.failed:
      case TaskStatus.stopped:            return const Color(0xffff6b6b);
      default:                            return const Color(0xff56d19a);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: const Color(0xff10131a),
      child: Column(children: [
        // Header
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: Color(0xff141820),
            border: Border(bottom: BorderSide(color: Color(0xff2a303d))),
          ),
          child: Row(children: [
            const Text('✦', style: TextStyle(color: Color(0xff8da5ff), fontSize: 16)),
            const SizedBox(width: 8),
            const Text('Brigade Bridge',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(_statusLabel,
                style: TextStyle(fontSize: 9, color: _statusColor,
                    fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ]),
        ),
        // Node list
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('NODES',
                    style: TextStyle(fontSize: 9, color: Color(0xff737e92),
                        letterSpacing: 1.4, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...nodes.map((n) => NodeChip(node: n)),
                const Spacer(),
                // Log tail
                if (logTail.isNotEmpty)
                  Text('● $logTail',
                      style: const TextStyle(fontSize: 9, color: Color(0xff7d8798)),
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
        // Action bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xff2a303d))),
          ),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onExpand,
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8)),
                child: const Text('Expand', style: TextStyle(fontSize: 11)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: onStop,
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8)),
                child: const Text('Stop', style: TextStyle(fontSize: 11)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: onRun,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8)),
                child: const Text('Run', style: TextStyle(fontSize: 11)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
```

- [ ] **Step 5: Run tests**

```bash
flutter test test/ui/compact_hud_test.dart
```
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/ui/compact_hud.dart lib/ui/node_chip.dart test/ui/compact_hud_test.dart
git commit -m "feat: CompactHud widget and NodeChip"
```

---

### Task 4: Expanded editor widget (sidebar + canvas + inspector)

**Files:**
- Create: `lib/ui/expanded_editor.dart`
- Create: `lib/ui/node_canvas.dart`
- Create: `lib/ui/activity_inspector.dart`
- Create: `lib/ui/approval_modal.dart`

**Interfaces:**
- Consumes: `BridgeNode`, `BridgeTask`, `TaskStatus`, `NodeEdge` (add `NodeEdge` to bridge_models.dart as `class NodeEdge { final String from; final String to; const NodeEdge(this.from, this.to); }`)
- Produces:
  - `ExpandedEditor(nodes, edges, tasks, onAddEdge, onRun, onStop, onCompact, onDispatch, onApprove, onDeny)` widget
  - `ApprovalModal.show(context, task, onApprove, onDeny)` static method

- [ ] **Step 1: Add NodeEdge to bridge_models.dart**

Append to `lib/core/bridge_models.dart`:
```dart
class NodeEdge {
  const NodeEdge(this.from, this.to);
  final String from;
  final String to;
}
```

- [ ] **Step 2: Write widget tests**

Create `test/ui/expanded_editor_test.dart`:
```dart
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
```

- [ ] **Step 3: Run test to verify it fails**

```bash
flutter test test/ui/expanded_editor_test.dart
```
Expected: FAIL — `expanded_editor.dart` not found.

- [ ] **Step 4: Create lib/ui/node_canvas.dart**

```dart
import 'package:flutter/material.dart';
import '../core/bridge_models.dart';

class NodeCanvas extends StatelessWidget {
  const NodeCanvas({super.key, required this.nodes, required this.edges,
      this.selectedId, this.onNodeTap});
  final List<BridgeNode> nodes;
  final List<NodeEdge> edges;
  final String? selectedId;
  final void Function(String id)? onNodeTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      // Static grid positions: up to 6 nodes, 2 columns
      final positions = _gridPositions(nodes.length, w, h);
      return Stack(children: [
        // Edge layer
        CustomPaint(
          size: Size(w, h),
          painter: _EdgePainter(nodes: nodes, edges: edges, positions: positions),
        ),
        // Node cards
        ...nodes.asMap().entries.map((e) {
          final pos = positions[e.key];
          final n = e.value;
          final selected = selectedId == n.id;
          return Positioned(
            left: pos.dx, top: pos.dy,
            child: GestureDetector(
              onTap: () => onNodeTap?.call(n.id),
              child: _NodeCard(node: n, selected: selected),
            ),
          );
        }),
        const Positioned(
          bottom: 14, left: 16,
          child: Text('Click a node, then another to connect',
              style: TextStyle(fontSize: 9, color: Color(0xff657084))),
        ),
      ]);
    });
  }

  List<Offset> _gridPositions(int count, double w, double h) {
    const cols = 2;
    final colW = w / cols;
    final rowH = h / ((count / cols).ceil() + 1);
    return List.generate(count, (i) => Offset(
      colW * (i % cols) + colW * 0.15,
      rowH * (i ~/ cols + 1) - 60,
    ));
  }
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({required this.node, required this.selected});
  final BridgeNode node;
  final bool selected;

  Color get _accent {
    switch (node.kind) {
      case NodeKind.agent:   return const Color(0xff7188ff);
      case NodeKind.browser: return const Color(0xffad81ff);
      case NodeKind.terminal: return const Color(0xfff2a65a);
      case NodeKind.desktop: return const Color(0xff56d19a);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff1a1f29),
        border: Border.all(
          color: selected ? const Color(0xff7f95ff) : const Color(0xff374153),
          width: selected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(node.kind == NodeKind.agent ? '✦' :
               node.kind == NodeKind.browser ? '◈' :
               node.kind == NodeKind.terminal ? '⌘' : '◉',
              style: TextStyle(color: _accent)),
          const SizedBox(width: 8),
          Text(node.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        Text(node.detail, style: const TextStyle(fontSize: 10, color: Color(0xff798497))),
        const SizedBox(height: 8),
        const Text('● READY · LOCAL SESSION',
            style: TextStyle(fontSize: 8, color: Color(0xff70d3a4))),
      ]),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({required this.nodes, required this.edges, required this.positions});
  final List<BridgeNode> nodes;
  final List<NodeEdge> edges;
  final List<Offset> positions;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xff7188ff).withValues(alpha: .6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final arrowPaint = Paint()
      ..color = const Color(0xff7188ff).withValues(alpha: .6)
      ..style = PaintingStyle.fill;

    for (final edge in edges) {
      final fromIdx = nodes.indexWhere((n) => n.id == edge.from);
      final toIdx = nodes.indexWhere((n) => n.id == edge.to);
      if (fromIdx < 0 || toIdx < 0) continue;
      final from = positions[fromIdx] + const Offset(90, 30);
      final to = positions[toIdx] + const Offset(0, 30);
      canvas.drawLine(from, to, paint);
      // Arrow head
      final dir = (to - from);
      final len = dir.distance;
      if (len < 1) continue;
      final unit = dir / len;
      final tip = to;
      final left = tip - unit * 10 + Offset(-unit.dy, unit.dx) * 5;
      final right = tip - unit * 10 - Offset(-unit.dy, unit.dx) * 5;
      canvas.drawPath(Path()..moveTo(tip.dx, tip.dy)..lineTo(left.dx, left.dy)
          ..lineTo(right.dx, right.dy)..close(), arrowPaint);
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.edges != edges || old.nodes != nodes;
}
```

- [ ] **Step 5: Create lib/ui/activity_inspector.dart**

```dart
import 'package:flutter/material.dart';
import '../core/bridge_models.dart';

class ActivityInspector extends StatelessWidget {
  const ActivityInspector({
    super.key,
    required this.logEntries,
    required this.status,
    required this.onDispatch,
  });
  final List<String> logEntries;
  final TaskStatus status;
  final void Function(String text) onDispatch;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return Container(
      width: 300,
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: Color(0xff171b24),
        border: Border(left: BorderSide(color: Color(0xff2a303d))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('ACTIVITY',
            style: TextStyle(fontSize: 9, color: Color(0xff737e92),
                letterSpacing: 1.4, fontWeight: FontWeight.bold)),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Task stream', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          Text(_statusLabel(status),
              style: TextStyle(fontSize: 9, color: _statusColor(status),
                  fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 14),
        TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(fontSize: 12),
          decoration: const InputDecoration(
            filled: true,
            fillColor: Color(0xff151a23),
            hintText: 'Enter task instruction…',
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => onDispatch(controller.text),
            child: const Text('Dispatch task', style: TextStyle(fontSize: 12)),
          ),
        ),
        const SizedBox(height: 18),
        const Text('EVENT LOG',
            style: TextStyle(fontSize: 9, color: Color(0xff737e92),
                letterSpacing: 1.4, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            reverse: true,
            itemCount: logEntries.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('● ${logEntries[i]}',
                  style: const TextStyle(fontSize: 10, color: Color(0xffa4adbd))),
            ),
          ),
        ),
        const Divider(color: Color(0xff2a303d)),
        const SizedBox(height: 10),
        const Text('PERMISSIONS',
            style: TextStyle(fontSize: 9, color: Color(0xff737e92),
                letterSpacing: 1.4, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('⌾  Read-only by default',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        const Text('     Text input requires approval',
            style: TextStyle(fontSize: 10, color: Color(0xff7d8798))),
      ]),
    );
  }

  String _statusLabel(TaskStatus s) {
    switch (s) {
      case TaskStatus.working: return 'RUNNING';
      case TaskStatus.waitingForApproval: return 'WAITING';
      case TaskStatus.completed: return 'DONE';
      case TaskStatus.failed: return 'FAILED';
      case TaskStatus.stopped: return 'STOPPED';
      default: return 'READY';
    }
  }

  Color _statusColor(TaskStatus s) {
    switch (s) {
      case TaskStatus.working: return const Color(0xff9fb1ff);
      case TaskStatus.waitingForApproval: return const Color(0xfff2a65a);
      case TaskStatus.failed:
      case TaskStatus.stopped: return const Color(0xffff6b6b);
      default: return const Color(0xff56d19a);
    }
  }
}
```

- [ ] **Step 6: Create lib/ui/approval_modal.dart**

```dart
import 'package:flutter/material.dart';
import '../core/bridge_models.dart';

class ApprovalModal {
  static Future<ApprovalDecision?> show(
    BuildContext context, {
    required BridgeTask task,
    required String sourceName,
    required String targetName,
  }) {
    return showDialog<ApprovalDecision>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xff1a1f2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(children: [
          Text('⚠', style: TextStyle(fontSize: 18)),
          SizedBox(width: 10),
          Text('Approval required', style: TextStyle(fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$sourceName wants to send text to $targetName',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xff10131a),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                task.instruction.length > 120
                    ? '${task.instruction.substring(0, 120)}…'
                    : task.instruction,
                style: const TextStyle(fontSize: 11, color: Color(0xff9ca8b9)),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ApprovalDecision.denyAll),
            child: const Text('Deny all', style: TextStyle(color: Color(0xffff6b6b))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ApprovalDecision.deny),
            child: const Text('Deny'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ApprovalDecision.approveOnce),
            child: const Text('Approve once'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ApprovalDecision.alwaysAllow),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xff56d19a)),
            child: const Text('Always allow',
                style: TextStyle(color: Color(0xff10131a))),
          ),
        ],
      ),
    );
  }
}

enum ApprovalDecision { approveOnce, alwaysAllow, deny, denyAll }
```

- [ ] **Step 7: Create lib/ui/expanded_editor.dart**

```dart
import 'package:flutter/material.dart';
import '../core/bridge_models.dart';
import 'node_canvas.dart';
import 'activity_inspector.dart';

class ExpandedEditor extends StatefulWidget {
  const ExpandedEditor({
    super.key,
    required this.nodes,
    required this.edges,
    required this.tasks,
    required this.onAddEdge,
    required this.onRun,
    required this.onStop,
    required this.onCompact,
    required this.onDispatch,
    required this.onApprove,
    required this.onDeny,
    required this.logEntries,
    required this.status,
  });

  final List<BridgeNode> nodes;
  final List<NodeEdge> edges;
  final List<BridgeTask> tasks;
  final void Function(String from, String to) onAddEdge;
  final VoidCallback onRun;
  final VoidCallback onStop;
  final VoidCallback onCompact;
  final void Function(String text) onDispatch;
  final void Function(String taskId) onApprove;
  final void Function(String taskId) onDeny;
  final List<String> logEntries;
  final TaskStatus status;

  @override
  State<ExpandedEditor> createState() => _ExpandedEditorState();
}

class _ExpandedEditorState extends State<ExpandedEditor> {
  String? _pendingFrom;
  final _nameController = TextEditingController(text: 'Research → build → verify');

  void _handleNodeTap(String id) {
    if (_pendingFrom == null) {
      setState(() => _pendingFrom = id);
    } else if (_pendingFrom != id) {
      widget.onAddEdge(_pendingFrom!, id);
      setState(() => _pendingFrom = null);
    } else {
      setState(() => _pendingFrom = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff10131a),
      body: Column(children: [
        // Top bar
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(
            color: Color(0xff141820),
            border: Border(bottom: BorderSide(color: Color(0xff2a303d))),
          ),
          child: Row(children: [
            const Text('✦', style: TextStyle(color: Color(0xff8da5ff), fontSize: 20)),
            const SizedBox(width: 10),
            const Text('Brigade Bridge',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(width: 12),
            const Text('LOCAL ORCHESTRATOR',
                style: TextStyle(fontSize: 8, color: Color(0xff707a8c), letterSpacing: 1.5)),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: widget.onCompact,
              icon: const Icon(Icons.compress, size: 12),
              label: const Text('Compact', style: TextStyle(fontSize: 11)),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: widget.onStop,
              icon: const Icon(Icons.stop, size: 12),
              label: const Text('Stop', style: TextStyle(fontSize: 11)),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: widget.onRun,
              icon: const Icon(Icons.play_arrow, size: 14),
              label: const Text('Run workflow', style: TextStyle(fontSize: 11)),
            ),
          ]),
        ),
        // Three-column body
        Expanded(child: Row(children: [
          // Sidebar
          Container(
            width: 240,
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Color(0xff171b24),
              border: Border(right: BorderSide(color: Color(0xff2a303d))),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('WORKFLOW',
                  style: TextStyle(fontSize: 9, color: Color(0xff737e92),
                      letterSpacing: 1.4, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Build a brigade',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Connect tools open on your computer. No API keys.',
                  style: TextStyle(fontSize: 11, height: 1.5, color: Color(0xff8790a2))),
              const SizedBox(height: 18),
              const Text('WORKFLOW NAME',
                  style: TextStyle(fontSize: 9, color: Color(0xff8b95a8))),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(hintText: 'Research → build → verify'),
              ),
              const SizedBox(height: 20),
              const Text('AVAILABLE NODES',
                  style: TextStyle(fontSize: 9, color: Color(0xff737e92),
                      letterSpacing: 1.4, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...widget.nodes.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('${n.kind == NodeKind.agent ? "✦" : "◈"}  ${n.name}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _pendingFrom == n.id
                          ? const Color(0xff7f95ff)
                          : const Color(0xffcdd6f4),
                    )),
              )),
              const Spacer(),
              const Divider(color: Color(0xff2a303d)),
              const SizedBox(height: 8),
              const Text('● Bridge daemon online',
                  style: TextStyle(fontSize: 10, color: Color(0xff9ca8b9))),
              const Text('   Listening on localhost:7432',
                  style: TextStyle(fontSize: 9, color: Color(0xff7d8798))),
            ]),
          ),
          // Canvas
          Expanded(
            child: Container(
              color: const Color(0xff11151c),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('CANVAS / DRAFT',
                          style: TextStyle(fontSize: 9, color: Color(0xff737e92),
                              letterSpacing: 1.4)),
                      Text(_nameController.text,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ]),
                    const Spacer(),
                    if (_pendingFrom != null)
                      Text('Now click the target node',
                          style: const TextStyle(fontSize: 10, color: Color(0xff7f95ff))),
                  ]),
                ),
                Expanded(
                  child: NodeCanvas(
                    nodes: widget.nodes,
                    edges: widget.edges,
                    selectedId: _pendingFrom,
                    onNodeTap: _handleNodeTap,
                  ),
                ),
              ]),
            ),
          ),
          // Inspector
          ActivityInspector(
            logEntries: widget.logEntries,
            status: widget.status,
            onDispatch: widget.onDispatch,
          ),
        ])),
      ]),
    );
  }
}
```

- [ ] **Step 8: Run tests**

```bash
flutter test test/ui/expanded_editor_test.dart
```
Expected: PASS (1 test).

- [ ] **Step 9: Commit**

```bash
git add lib/ui/expanded_editor.dart lib/ui/node_canvas.dart \
        lib/ui/activity_inspector.dart lib/ui/approval_modal.dart \
        lib/core/bridge_models.dart test/ui/expanded_editor_test.dart
git commit -m "feat: ExpandedEditor, NodeCanvas, ActivityInspector, ApprovalModal"
```

---

### Task 5: Overlay shell — mode toggle, hotkey, Home widget

**Files:**
- Modify: `lib/main.dart` (replace placeholder Home with real shell)
- Create: `lib/ui/overlay_shell.dart`

**Interfaces:**
- Consumes: `CompactHud`, `ExpandedEditor`, `BridgeChannel.onHotKeyFired`
- Produces: `OverlayShell` — the root widget managing compact↔expanded transition and hotkey subscription

- [ ] **Step 1: Write test**

Create `test/ui/overlay_shell_test.dart`:
```dart
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
```

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/ui/overlay_shell_test.dart
```
Expected: FAIL — `overlay_shell.dart` not found.

- [ ] **Step 3: Create lib/ui/overlay_shell.dart**

```dart
import 'package:flutter/material.dart';
import '../core/bridge_models.dart';
import 'compact_hud.dart';
import 'expanded_editor.dart';

class OverlayShell extends StatefulWidget {
  const OverlayShell({
    super.key,
    required this.nodes,
    required this.edges,
    required this.tasks,
    required this.logEntries,
    required this.onRun,
    required this.onStop,
    required this.onAddEdge,
    required this.onDispatch,
    required this.onApprove,
    required this.onDeny,
    required this.status,
    required this.logTail,
  });

  final List<BridgeNode> nodes;
  final List<NodeEdge> edges;
  final List<BridgeTask> tasks;
  final List<String> logEntries;
  final VoidCallback onRun;
  final VoidCallback onStop;
  final void Function(String from, String to) onAddEdge;
  final void Function(String text) onDispatch;
  final void Function(String taskId) onApprove;
  final void Function(String taskId) onDeny;
  final TaskStatus status;
  final String logTail;

  @override
  State<OverlayShell> createState() => _OverlayShellState();
}

class _OverlayShellState extends State<OverlayShell> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _expanded
          ? ExpandedEditor(
              key: const ValueKey('expanded'),
              nodes: widget.nodes,
              edges: widget.edges,
              tasks: widget.tasks,
              onAddEdge: widget.onAddEdge,
              onRun: widget.onRun,
              onStop: widget.onStop,
              onCompact: () => setState(() => _expanded = false),
              onDispatch: widget.onDispatch,
              onApprove: widget.onApprove,
              onDeny: widget.onDeny,
              logEntries: widget.logEntries,
              status: widget.status,
            )
          : CompactHud(
              key: const ValueKey('compact'),
              nodes: widget.nodes,
              onExpand: () => setState(() => _expanded = true),
              onRun: widget.onRun,
              onStop: widget.onStop,
              logTail: widget.logTail,
              status: widget.status,
            ),
    );
  }
}
```

- [ ] **Step 4: Replace Home in lib/main.dart with OverlayShell**

Replace the old `Home`/`_HomeState` classes in `lib/main.dart` with:
```dart
import 'package:flutter/material.dart';
import 'core/bridge_models.dart';
import 'platform/bridge_channel.dart';
import 'ui/overlay_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  BridgeChannel.init();
  runApp(const BridgeApp());
}

class BridgeApp extends StatelessWidget {
  const BridgeApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Brigade Bridge',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xff10131a),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff7188ff),
          brightness: Brightness.dark,
        ),
      ),
      home: const _AppShell(),
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell();
  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  final List<BridgeNode> _nodes = [];
  final List<NodeEdge> _edges = [];
  final List<BridgeTask> _tasks = [];
  final List<String> _log = [];
  TaskStatus _status = TaskStatus.created;

  @override
  void initState() {
    super.initState();
    BridgeChannel.onHotKeyFired.listen((_) {
      // Toggle show/hide — handled by BridgeChannel natively;
      // also trigger a UI refresh if needed
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return OverlayShell(
      nodes: _nodes,
      edges: _edges,
      tasks: _tasks,
      logEntries: _log,
      status: _status,
      logTail: _log.isNotEmpty ? _log.first : 'Bridge starting…',
      onRun: () => setState(() { _status = TaskStatus.working; _log.insert(0, 'Workflow dispatched'); }),
      onStop: () => setState(() { _status = TaskStatus.stopped; _log.insert(0, 'Emergency stop'); }),
      onAddEdge: (f, t) => setState(() => _edges.add(NodeEdge(f, t))),
      onDispatch: (text) => setState(() => _log.insert(0, 'Task dispatched: $text')),
      onApprove: (id) => setState(() => _log.insert(0, 'Task approved: $id')),
      onDeny: (id) => setState(() => _log.insert(0, 'Task denied: $id')),
    );
  }
}
```

- [ ] **Step 5: Run tests**

```bash
flutter test test/ui/overlay_shell_test.dart
```
Expected: PASS (2 tests).

- [ ] **Step 6: Build and smoke-test manually**

```bash
flutter build macos --debug && \
open build/macos/Build/Products/Debug/brigade_bridge.app
```
Expected: compact HUD appears with ✦ in menu bar; clicking Expand shows full editor; clicking Compact returns to HUD.

- [ ] **Step 7: Commit**

```bash
git add lib/ui/overlay_shell.dart lib/main.dart test/ui/overlay_shell_test.dart
git commit -m "feat: OverlayShell compact/expanded mode toggle, hotkey wiring"
```

---

## Phase 2 — Local Daemon (Dart Isolate)

### Task 6: SQLite schema with drift

**Files:**
- Create: `lib/daemon/database.dart`
- Create: `lib/daemon/database.g.dart` (generated)

**Interfaces:**
- Produces:
  - `BridgeDatabase` class (extends `GeneratedDatabase`)
  - DAOs: `NodesDao`, `WorkflowsDao`, `TasksDao`, `AuditDao`
  - `db.nodes.insertNode(...)`, `db.tasks.upsertTask(...)`, `db.audit.log(...)`

- [ ] **Step 1: Create lib/daemon/database.dart**

```dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

// ── Tables ────────────────────────────────────────────────────────────────────

class Nodes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get kind => text()();
  TextColumn get url => text().nullable()();
  IntColumn get tabId => integer().nullable()();
  TextColumn get permissionTier => text().withDefault(const Constant('read_only'))();
  TextColumn get health => text().withDefault(const Constant('healthy'))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Workflows extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get graphJson => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get workflowId => text().nullable()();
  TextColumn get sourceNode => text()();
  TextColumn get targetNode => text()();
  TextColumn get instruction => text()();
  TextColumn get status => text().withDefault(const Constant('created'))();
  TextColumn get result => text().nullable()();
  TextColumn get error => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class AuditLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ts => integer()();
  TextColumn get nodeId => text()();
  TextColumn get capability => text()();
  TextColumn get decision => text()();
  TextColumn get taskId => text()();
}

// ── DAOs ──────────────────────────────────────────────────────────────────────

@DriftAccessor(tables: [Nodes])
class NodesDao extends DatabaseAccessor<BridgeDatabase> with _$NodesDaoMixin {
  NodesDao(super.db);

  Future<void> upsertNode(NodesCompanion node) =>
      into(nodes).insertOnConflictUpdate(node);

  Future<List<Node>> allNodes() => select(nodes).get();

  Future<void> updateHealth(String id, String health) =>
      (update(nodes)..where((t) => t.id.equals(id)))
          .write(NodesCompanion(health: Value(health)));
}

@DriftAccessor(tables: [Workflows])
class WorkflowsDao extends DatabaseAccessor<BridgeDatabase>
    with _$WorkflowsDaoMixin {
  WorkflowsDao(super.db);

  Future<void> upsertWorkflow(WorkflowsCompanion wf) =>
      into(workflows).insertOnConflictUpdate(wf);

  Future<List<Workflow>> allWorkflows() => select(workflows).get();
}

@DriftAccessor(tables: [Tasks])
class TasksDao extends DatabaseAccessor<BridgeDatabase> with _$TasksDaoMixin {
  TasksDao(super.db);

  Future<void> upsertTask(TasksCompanion task) =>
      into(tasks).insertOnConflictUpdate(task);

  Future<List<Task>> incompleteTasks() =>
      (select(tasks)
            ..where((t) => t.status.isNotIn(['completed', 'cancelled', 'failed'])))
          .get();

  Future<void> updateStatus(String id, String status, {String? result, String? error}) =>
      (update(tasks)..where((t) => t.id.equals(id))).write(TasksCompanion(
        status: Value(status),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        if (result != null) result: Value(result),
        if (error != null) error: Value(error),
      ));
}

@DriftAccessor(tables: [AuditLog])
class AuditDao extends DatabaseAccessor<BridgeDatabase> with _$AuditDaoMixin {
  AuditDao(super.db);

  Future<void> log({
    required String nodeId,
    required String capability,
    required String decision,
    required String taskId,
  }) =>
      into(auditLog).insert(AuditLogCompanion.insert(
        ts: DateTime.now().millisecondsSinceEpoch,
        nodeId: nodeId,
        capability: capability,
        decision: decision,
        taskId: taskId,
      ));

  Future<List<AuditLogData>> recent({int limit = 100}) =>
      (select(auditLog)..orderBy([(t) => OrderingTerm.desc(t.ts)])..limit(limit))
          .get();
}

// ── Database ──────────────────────────────────────────────────────────────────

@DriftDatabase(
  tables: [Nodes, Workflows, Tasks, AuditLog],
  daos: [NodesDao, WorkflowsDao, TasksDao, AuditDao],
)
class BridgeDatabase extends _$BridgeDatabase {
  BridgeDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;

  static Future<BridgeDatabase> open() async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'BrigadeBridge', 'brigade.db');
    await Directory(p.dirname(dbPath)).create(recursive: true);
    return BridgeDatabase(NativeDatabase(File(dbPath)));
  }
}
```

- [ ] **Step 2: Run drift code generation**

```bash
cd "/Users/anaslari/Downloads/brigade bridge"
dart run build_runner build --delete-conflicting-outputs
```
Expected: `lib/daemon/database.g.dart` created with no errors.

- [ ] **Step 3: Write integration test**

Create `test/daemon/database_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brigade_bridge/daemon/database.dart';
import 'package:drift/drift.dart';

BridgeDatabase openInMemory() =>
    BridgeDatabase(NativeDatabase.memory());

void main() {
  late BridgeDatabase db;
  setUp(() => db = openInMemory());
  tearDown(() => db.close());

  test('insert and retrieve node', () async {
    await db.nodes.upsertNode(NodesCompanion.insert(
      id: 'n1', name: 'Codex', kind: 'agent',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    final all = await db.nodes.allNodes();
    expect(all.length, 1);
    expect(all.first.name, 'Codex');
    expect(all.first.permissionTier, 'read_only');
  });

  test('task status update', () async {
    await db.tasks.upsertTask(TasksCompanion.insert(
      id: 't1', sourceNode: 'n1', targetNode: 'n2',
      instruction: 'test',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
    await db.tasks.updateStatus('t1', 'completed', result: 'done');
    final tasks = await db.tasks.incompleteTasks();
    expect(tasks.isEmpty, isTrue);
  });

  test('audit log records entries', () async {
    await db.audit.log(
        nodeId: 'n1', capability: 'send_text',
        decision: 'approved', taskId: 't1');
    final log = await db.audit.recent();
    expect(log.length, 1);
    expect(log.first.capability, 'send_text');
  });
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/daemon/database_test.dart
```
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/daemon/database.dart lib/daemon/database.g.dart \
        test/daemon/database_test.dart
git commit -m "feat: drift SQLite schema — nodes, workflows, tasks, audit_log"
```

---

### Task 7: event_bus and node_registry

**Files:**
- Create: `lib/daemon/event_bus.dart`
- Create: `lib/daemon/node_registry.dart`

**Interfaces:**
- Produces:
  - `EventBus` singleton with `publish(DaemonEvent)` and `Stream<DaemonEvent> stream`
  - `DaemonEvent` sealed class with subtypes: `NodeRegistered`, `TaskStatusChanged`, `ApprovalRequired`, `AdapterHealth`, `LogEntry`
  - `NodeRegistry(db, eventBus)` with `register(BridgeNode)`, `allNodes()`, `updateHealth(id, health)`

- [ ] **Step 1: Create lib/daemon/event_bus.dart**

```dart
import 'dart:async';
import '../core/bridge_models.dart';

// ── Event types ───────────────────────────────────────────────────────────────

sealed class DaemonEvent {}

class NodeRegistered extends DaemonEvent {
  NodeRegistered(this.node);
  final BridgeNode node;
}

class TaskStatusChanged extends DaemonEvent {
  TaskStatusChanged(this.taskId, this.status, {this.result, this.error});
  final String taskId;
  final TaskStatus status;
  final String? result;
  final String? error;
}

class ApprovalRequired extends DaemonEvent {
  ApprovalRequired(this.task, this.sourceName, this.targetName);
  final BridgeTask task;
  final String sourceName;
  final String targetName;
}

class AdapterHealthEvent extends DaemonEvent {
  AdapterHealthEvent(this.nodeId, this.health);
  final String nodeId;
  final String health; // healthy | degraded | unavailable | requires_update
}

class LogEntry extends DaemonEvent {
  LogEntry(this.message, {this.severity = 'info'});
  final String message;
  final String severity; // info | warning | emergency
}

// ── Bus ───────────────────────────────────────────────────────────────────────

class EventBus {
  final _controller = StreamController<DaemonEvent>.broadcast();
  Stream<DaemonEvent> get stream => _controller.stream;

  void publish(DaemonEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  void dispose() => _controller.close();
}
```

- [ ] **Step 2: Create lib/daemon/node_registry.dart**

```dart
import '../core/bridge_models.dart';
import 'database.dart';
import 'event_bus.dart';
import 'package:drift/drift.dart';

class NodeRegistry {
  NodeRegistry(this._db, this._bus);
  final BridgeDatabase _db;
  final EventBus _bus;

  Future<void> register(BridgeNode node) async {
    await _db.nodes.upsertNode(NodesCompanion(
      id: Value(node.id),
      name: Value(node.name),
      kind: Value(node.kind.name),
      url: Value(node.url),
      tabId: Value(node.tabId),
      createdAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
    _bus.publish(NodeRegistered(node));
    _bus.publish(LogEntry('Node registered: ${node.name}'));
  }

  Future<List<BridgeNode>> allNodes() async {
    final rows = await _db.nodes.allNodes();
    return rows.map((r) => BridgeNode(
      id: r.id,
      name: r.name,
      kind: NodeKind.values.firstWhere((k) => k.name == r.kind),
      detail: r.url ?? '',
      tabId: r.tabId,
      url: r.url,
    )).toList();
  }

  Future<void> updateHealth(String nodeId, String health) async {
    await _db.nodes.updateHealth(nodeId, health);
    _bus.publish(AdapterHealthEvent(nodeId, health));
  }
}
```

- [ ] **Step 3: Update BridgeNode model to carry tabId and url**

In `lib/core/bridge_models.dart`, replace `BridgeNode`:
```dart
class BridgeNode {
  const BridgeNode({
    required this.id,
    required this.name,
    required this.kind,
    required this.detail,
    this.capabilities = const [],
    this.tabId,
    this.url,
  });
  final String id;
  final String name;
  final NodeKind kind;
  final String detail;
  final List<String> capabilities;
  final int? tabId;
  final String? url;
}
```

- [ ] **Step 4: Write tests**

Create `test/daemon/node_registry_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brigade_bridge/daemon/database.dart';
import 'package:brigade_bridge/daemon/event_bus.dart';
import 'package:brigade_bridge/daemon/node_registry.dart';
import 'package:brigade_bridge/core/bridge_models.dart';

void main() {
  late BridgeDatabase db;
  late EventBus bus;
  late NodeRegistry registry;

  setUp(() {
    db = BridgeDatabase(NativeDatabase.memory());
    bus = EventBus();
    registry = NodeRegistry(db, bus);
  });
  tearDown(() async { await db.close(); bus.dispose(); });

  test('register emits NodeRegistered event', () async {
    final events = <DaemonEvent>[];
    bus.stream.listen(events.add);

    await registry.register(const BridgeNode(
        id: 'c1', name: 'Codex', kind: NodeKind.agent, detail: 'Tab 2'));

    await Future.delayed(Duration.zero);
    expect(events.whereType<NodeRegistered>().length, 1);
  });

  test('allNodes returns registered nodes', () async {
    await registry.register(const BridgeNode(
        id: 'c1', name: 'Codex', kind: NodeKind.agent, detail: 'Tab 2'));
    final nodes = await registry.allNodes();
    expect(nodes.length, 1);
    expect(nodes.first.name, 'Codex');
  });
}
```

- [ ] **Step 5: Run tests**

```bash
flutter test test/daemon/node_registry_test.dart
```
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/daemon/event_bus.dart lib/daemon/node_registry.dart \
        lib/core/bridge_models.dart test/daemon/node_registry_test.dart
git commit -m "feat: EventBus, NodeRegistry, extended BridgeNode model"
```

---

### Task 8: permission_manager

**Files:**
- Create: `lib/daemon/permission_manager.dart`

**Interfaces:**
- Produces:
  - `PermissionManager(db, bus)`
  - `Future<bool> checkAndRequest(String nodeId, String capability, BridgeTask task)` — returns `true` if allowed, emits `ApprovalRequired` and waits if tier insufficient
  - `void approve(String taskId)` — resumes a waiting task
  - `void deny(String taskId)` — cancels a waiting task

- [ ] **Step 1: Write test**

Create `test/daemon/permission_manager_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brigade_bridge/daemon/database.dart';
import 'package:brigade_bridge/daemon/event_bus.dart';
import 'package:brigade_bridge/daemon/permission_manager.dart';
import 'package:brigade_bridge/core/bridge_models.dart';
import 'package:drift/drift.dart';

BridgeDatabase memDb() => BridgeDatabase(NativeDatabase.memory());

void main() {
  late BridgeDatabase db;
  late EventBus bus;
  late PermissionManager pm;

  setUp(() async {
    db = memDb();
    bus = EventBus();
    pm = PermissionManager(db, bus);
    // Insert a read_only node
    await db.nodes.upsertNode(NodesCompanion.insert(
      id: 'n1', name: 'Codex', kind: 'agent',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
  });
  tearDown(() async { await db.close(); bus.dispose(); });

  test('read_text allowed on read_only node without approval', () async {
    final task = BridgeTask(
        id: 't1', sourceNodeId: 'x', targetNodeId: 'n1',
        instruction: 'test');
    final ok = await pm.checkAndRequest('n1', 'read_text', task);
    expect(ok, isTrue);
    // No ApprovalRequired event
    final events = <DaemonEvent>[];
    bus.stream.listen(events.add);
    await Future.delayed(Duration.zero);
    expect(events.whereType<ApprovalRequired>().length, 0);
  });

  test('send_text on read_only node emits ApprovalRequired', () async {
    final events = <DaemonEvent>[];
    bus.stream.listen(events.add);

    final task = BridgeTask(
        id: 't2', sourceNodeId: 'x', targetNodeId: 'n1',
        instruction: 'hello');

    // Don't await — it will pause waiting for approval
    final futureResult = pm.checkAndRequest('n1', 'send_text', task);
    await Future.delayed(const Duration(milliseconds: 50));

    expect(events.whereType<ApprovalRequired>().length, 1);
    pm.approve('t2');

    final result = await futureResult;
    expect(result, isTrue);
  });

  test('deny cancels waiting task', () async {
    final task = BridgeTask(
        id: 't3', sourceNodeId: 'x', targetNodeId: 'n1',
        instruction: 'hello');
    final futureResult = pm.checkAndRequest('n1', 'send_text', task);
    await Future.delayed(const Duration(milliseconds: 50));
    pm.deny('t3');
    final result = await futureResult;
    expect(result, isFalse);
  });
}
```

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/daemon/permission_manager_test.dart
```
Expected: FAIL — `permission_manager.dart` not found.

- [ ] **Step 3: Create lib/daemon/permission_manager.dart**

```dart
import 'dart:async';
import 'package:drift/drift.dart';
import '../core/bridge_models.dart';
import 'database.dart';
import 'event_bus.dart';

const _tierRank = {
  'read_only': 0,
  'input': 1,
  'file': 2,
  'system': 3,
};

const _capabilityTier = {
  'read_text': 'read_only',
  'read_screen': 'read_only',
  'send_text': 'input',
  'click': 'input',
  'upload_file': 'file',
  'download_file': 'file',
  'run_command': 'system',
  'open_link': 'system',
};

class PermissionManager {
  PermissionManager(this._db, this._bus);
  final BridgeDatabase _db;
  final EventBus _bus;

  // taskId → Completer that resolves when user approves/denies
  final _pending = <String, Completer<bool>>{};

  /// Returns true if the capability is allowed (immediately or after approval).
  /// Emits ApprovalRequired and suspends until approve()/deny() is called.
  Future<bool> checkAndRequest(
      String nodeId, String capability, BridgeTask task) async {
    final rows = await (_db.select(_db.nodes)
          ..where((t) => t.id.equals(nodeId)))
        .get();
    if (rows.isEmpty) return false;

    final nodeTier = rows.first.permissionTier;
    final requiredTier = _capabilityTier[capability] ?? 'system';

    final nodeRank = _tierRank[nodeTier] ?? 0;
    final requiredRank = _tierRank[requiredTier] ?? 3;

    if (nodeRank >= requiredRank) {
      // Already allowed
      await _db.audit.log(
          nodeId: nodeId, capability: capability,
          decision: 'auto', taskId: task.id);
      return true;
    }

    // Need approval
    await _db.audit.log(
        nodeId: nodeId, capability: capability,
        decision: 'pending', taskId: task.id);

    final completer = Completer<bool>();
    _pending[task.id] = completer;

    final sourceNode = rows.first;
    _bus.publish(ApprovalRequired(task, sourceNode.name, task.targetNodeId));

    return completer.future;
  }

  void approve(String taskId) {
    final c = _pending.remove(taskId);
    if (c != null && !c.isCompleted) c.complete(true);
  }

  void deny(String taskId) {
    final c = _pending.remove(taskId);
    if (c != null && !c.isCompleted) c.complete(false);
  }

  void denyAll(List<String> taskIds) {
    for (final id in taskIds) deny(id);
  }
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/daemon/permission_manager_test.dart
```
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/daemon/permission_manager.dart test/daemon/permission_manager_test.dart
git commit -m "feat: PermissionManager — tier-based approval gate"
```

---

### Task 9: workflow_engine and task_scheduler

**Files:**
- Create: `lib/daemon/task_scheduler.dart`
- Create: `lib/daemon/workflow_engine.dart`
- Create: `lib/daemon/artifact_store.dart`

**Interfaces:**
- Consumes: `NodeRegistry`, `PermissionManager`, `EventBus`, `BridgeDatabase`
- Produces:
  - `WorkflowEngine(registry, scheduler, permissionManager, artifactStore, bus, db)`
  - `Future<void> run(List<BridgeNode> nodes, List<NodeEdge> edges, String taskText)` — executes graph sequentially
  - `void emergencyStop()` — cancels all active tasks
  - `ArtifactStore(supportDir)` with `Future<String> save(String taskId, String content)`

- [ ] **Step 1: Create lib/daemon/artifact_store.dart**

```dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';
import 'dart:convert';

class ArtifactStore {
  ArtifactStore(this._baseDir);
  final Directory _baseDir;

  Future<String> save(String taskId, String content) async {
    final dir = Directory(p.join(_baseDir.path, taskId));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, 'output.txt'));
    await file.writeAsString(content);
    final hash = sha256.convert(utf8.encode(content)).toString();
    final meta = File(p.join(dir.path, 'meta.json'));
    await meta.writeAsString(
        '{"taskId":"$taskId","contentHash":"$hash","ts":${DateTime.now().millisecondsSinceEpoch}}');
    return file.path;
  }

  Future<String?> read(String taskId) async {
    final file = File(p.join(_baseDir.path, taskId, 'output.txt'));
    if (await file.exists()) return file.readAsString();
    return null;
  }
}
```

Add `crypto: ^3.0.3` to `pubspec.yaml` dependencies, then run `flutter pub get`.

- [ ] **Step 2: Create lib/daemon/task_scheduler.dart**

```dart
import 'dart:async';
import '../core/bridge_models.dart';
import 'event_bus.dart';
import 'database.dart';
import 'package:drift/drift.dart';

typedef TaskHandler = Future<String?> Function(BridgeTask task);

class TaskScheduler {
  TaskScheduler(this._db, this._bus);
  final BridgeDatabase _db;
  final EventBus _bus;

  TaskHandler? _handler;
  bool _stopped = false;

  void setHandler(TaskHandler handler) => _handler = handler;

  void stop() => _stopped = true;
  void resume() => _stopped = false;

  Future<String?> dispatch(BridgeTask task) async {
    if (_stopped) {
      await _setStatus(task.id, 'cancelled');
      return null;
    }

    await _db.tasks.upsertTask(TasksCompanion.insert(
      id: task.id,
      sourceNode: task.sourceNodeId,
      targetNode: task.targetNodeId,
      instruction: task.instruction,
      createdAt: task.createdAt.millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));

    await _setStatus(task.id, 'queued');
    await _setStatus(task.id, 'working');

    try {
      final result = await _handler?.call(task);
      await _setStatus(task.id, 'completed', result: result);
      return result;
    } catch (e) {
      await _setStatus(task.id, 'failed', error: e.toString());
      return null;
    }
  }

  Future<void> _setStatus(String id, String status,
      {String? result, String? error}) async {
    await _db.tasks.updateStatus(id, status, result: result, error: error);
    _bus.publish(TaskStatusChanged(
      id,
      TaskStatus.values.firstWhere((s) => s.name == _dartStatus(status)),
      result: result,
      error: error,
    ));
    _bus.publish(LogEntry('Task $id → $status'));
  }

  String _dartStatus(String s) {
    const map = {
      'created': 'created',
      'queued': 'queued',
      'working': 'working',
      'waiting_for_approval': 'waitingForApproval',
      'completed': 'completed',
      'failed': 'failed',
      'cancelled': 'cancelled',
      'stopped': 'stopped',
    };
    return map[s] ?? 'created';
  }
}
```

- [ ] **Step 3: Create lib/daemon/workflow_engine.dart**

```dart
import 'dart:async';
import 'package:uuid/uuid.dart';
import '../core/bridge_models.dart';
import 'event_bus.dart';
import 'permission_manager.dart';
import 'task_scheduler.dart';
import 'artifact_store.dart';
import 'node_registry.dart';

class WorkflowEngine {
  WorkflowEngine({
    required this.registry,
    required this.scheduler,
    required this.permissionManager,
    required this.artifactStore,
    required this.bus,
  });

  final NodeRegistry registry;
  final TaskScheduler scheduler;
  final PermissionManager permissionManager;
  final ArtifactStore artifactStore;
  final EventBus bus;

  bool _stopped = false;
  final _uuid = const Uuid();

  // Injected by adapter_manager after construction
  Future<String?> Function(String nodeId, String text)? sendToAdapter;

  void emergencyStop() {
    _stopped = true;
    scheduler.stop();
    bus.publish(LogEntry('Emergency stop activated', severity: 'emergency'));
  }

  void reset() {
    _stopped = false;
    scheduler.resume();
  }

  Future<void> run({
    required List<BridgeNode> nodes,
    required List<NodeEdge> edges,
    required String taskText,
    String? workflowId,
  }) async {
    if (_stopped) return;

    bus.publish(LogEntry('Workflow started'));

    // Build ordered node sequence from edges
    final ordered = _topologicalOrder(nodes, edges);
    String carryText = taskText;

    for (final node in ordered) {
      if (_stopped) break;

      final task = BridgeTask(
        id: _uuid.v4(),
        sourceNodeId: ordered.indexOf(node) > 0
            ? ordered[ordered.indexOf(node) - 1].id
            : 'user',
        targetNodeId: node.id,
        instruction: carryText,
      );

      // Permission check
      final allowed = await permissionManager.checkAndRequest(
          node.id, 'send_text', task);
      if (!allowed || _stopped) {
        bus.publish(LogEntry('Task denied or stopped for ${node.name}'));
        break;
      }

      // Dispatch
      scheduler.setHandler((t) async {
        final result = await sendToAdapter?.call(node.id, t.instruction);
        if (result != null) {
          await artifactStore.save(t.id, result);
        }
        return result;
      });

      final result = await scheduler.dispatch(task);
      carryText = result ?? carryText; // carry output forward
    }

    if (!_stopped) bus.publish(LogEntry('Workflow completed'));
  }

  List<BridgeNode> _topologicalOrder(
      List<BridgeNode> nodes, List<NodeEdge> edges) {
    // For the first milestone: edges define a simple chain.
    // Walk edges from any node with no incoming edge.
    final inDegree = {for (final n in nodes) n.id: 0};
    for (final e in edges) {
      inDegree[e.to] = (inDegree[e.to] ?? 0) + 1;
    }
    final queue = nodes.where((n) => inDegree[n.id] == 0).toList();
    final result = <BridgeNode>[];
    while (queue.isNotEmpty) {
      final n = queue.removeAt(0);
      result.add(n);
      for (final e in edges.where((e) => e.from == n.id)) {
        final next = nodes.firstWhere((x) => x.id == e.to, orElse: () => n);
        inDegree[e.to] = (inDegree[e.to] ?? 1) - 1;
        if (inDegree[e.to] == 0) queue.add(next);
      }
    }
    return result;
  }
}
```

- [ ] **Step 4: Write tests**

Create `test/daemon/workflow_engine_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brigade_bridge/daemon/database.dart';
import 'package:brigade_bridge/daemon/event_bus.dart';
import 'package:brigade_bridge/daemon/node_registry.dart';
import 'package:brigade_bridge/daemon/permission_manager.dart';
import 'package:brigade_bridge/daemon/task_scheduler.dart';
import 'package:brigade_bridge/daemon/artifact_store.dart';
import 'package:brigade_bridge/daemon/workflow_engine.dart';
import 'package:brigade_bridge/core/bridge_models.dart';
import 'package:drift/drift.dart';
import 'dart:io';

void main() {
  late BridgeDatabase db;
  late EventBus bus;
  late WorkflowEngine engine;
  late Directory tmpDir;

  setUp(() async {
    db = BridgeDatabase(NativeDatabase.memory());
    bus = EventBus();
    final registry = NodeRegistry(db, bus);
    final pm = PermissionManager(db, bus);
    tmpDir = await Directory.systemTemp.createTemp('bridge_test_');
    final store = ArtifactStore(tmpDir);
    final scheduler = TaskScheduler(db, bus);
    engine = WorkflowEngine(
      registry: registry,
      scheduler: scheduler,
      permissionManager: pm,
      artifactStore: store,
      bus: bus,
    );

    // Insert nodes with 'input' tier so approval is auto-granted in tests
    for (final id in ['n1', 'n2']) {
      await db.nodes.upsertNode(NodesCompanion.insert(
        id: id, name: id, kind: 'agent',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
      await (db.update(db.nodes)..where((t) => t.id.equals(id)))
          .write(const NodesCompanion(permissionTier: Value('input')));
    }
  });
  tearDown(() async {
    await db.close();
    bus.dispose();
    await tmpDir.delete(recursive: true);
  });

  test('runs sequential workflow and passes output forward', () async {
    final received = <String>[];
    engine.sendToAdapter = (nodeId, text) async {
      received.add('$nodeId:$text');
      return 'result-from-$nodeId';
    };

    const nodes = [
      BridgeNode(id: 'n1', name: 'N1', kind: NodeKind.agent, detail: ''),
      BridgeNode(id: 'n2', name: 'N2', kind: NodeKind.agent, detail: ''),
    ];
    const edges = [NodeEdge('n1', 'n2')];

    await engine.run(nodes: nodes, edges: edges, taskText: 'initial');

    expect(received[0], 'n1:initial');
    expect(received[1], 'n2:result-from-n1');
  });

  test('emergency stop halts execution', () async {
    int callCount = 0;
    engine.sendToAdapter = (nodeId, text) async {
      callCount++;
      engine.emergencyStop();
      return 'r';
    };

    const nodes = [
      BridgeNode(id: 'n1', name: 'N1', kind: NodeKind.agent, detail: ''),
      BridgeNode(id: 'n2', name: 'N2', kind: NodeKind.agent, detail: ''),
    ];
    const edges = [NodeEdge('n1', 'n2')];

    await engine.run(nodes: nodes, edges: edges, taskText: 'go');
    expect(callCount, 1); // stopped after first node
  });
}
```

- [ ] **Step 5: Run tests**

```bash
flutter test test/daemon/workflow_engine_test.dart
```
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/daemon/task_scheduler.dart lib/daemon/workflow_engine.dart \
        lib/daemon/artifact_store.dart pubspec.yaml pubspec.lock \
        test/daemon/workflow_engine_test.dart
git commit -m "feat: TaskScheduler, WorkflowEngine (sequential), ArtifactStore"
```

---

### Task 10: Daemon bootstrap — Isolate + WebSocket server

**Files:**
- Create: `lib/daemon/daemon.dart`
- Create: `lib/daemon/ws_server.dart`
- Modify: `lib/main.dart` (spawn isolate)

**Interfaces:**
- Produces:
  - `Daemon.start()` — spawns isolate, returns `SendPort` for two-way comms
  - `WsServer(port, eventBus, engine, registry, pm)` — handles WebSocket connections
  - Flutter side receives `DaemonEvent` stream via `ReceivePort`

- [ ] **Step 1: Create lib/daemon/ws_server.dart**

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../core/bridge_models.dart';
import 'event_bus.dart';
import 'node_registry.dart';
import 'permission_manager.dart';
import 'workflow_engine.dart';

class WsServer {
  WsServer({
    required this.port,
    required this.bus,
    required this.engine,
    required this.registry,
    required this.pm,
  });

  final int port;
  final EventBus bus;
  final WorkflowEngine engine;
  final NodeRegistry registry;
  final PermissionManager pm;

  HttpServer? _server;
  final _clients = <WebSocket>[];

  // Extension adapter callbacks
  final _taskCompleters = <String, Completer<String?>>{};

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server!.transform(WebSocketTransformer()).listen(_onClient);

    // Forward daemon events to all connected clients
    bus.stream.listen(_broadcast);
  }

  void _onClient(WebSocket ws) {
    _clients.add(ws);
    ws.listen(
      (raw) => _handleMessage(ws, raw as String),
      onDone: () => _clients.remove(ws),
    );
  }

  void _handleMessage(WebSocket ws, String raw) {
    final msg = jsonDecode(raw) as Map<String, dynamic>;
    final type = msg['type'] as String;
    final payload = msg['payload'] as Map<String, dynamic>? ?? {};

    switch (type) {
      case 'REGISTER_TAB':
        final node = BridgeNode(
          id: 'tab-${payload['tabId']}',
          name: payload['identity'] as String? ?? payload['title'] as String,
          kind: NodeKind.browser,
          detail: payload['url'] as String,
          tabId: payload['tabId'] as int?,
          url: payload['url'] as String?,
        );
        registry.register(node);

      case 'TASK_RESULT':
        final taskId = payload['taskId'] as String;
        final output = payload['output'] as String?;
        _taskCompleters[taskId]?.complete(output);

      case 'ERROR':
        final taskId = payload['taskId'] as String;
        _taskCompleters[taskId]?.complete(null);

      case 'LIST_NODES':
        registry.allNodes().then((nodes) {
          ws.add(jsonEncode({
            'type': 'NODE_LIST',
            'payload': {'nodes': nodes.map((n) => {'id': n.id, 'name': n.name}).toList()},
          }));
        });

      case 'APPROVE_TASK':
        pm.approve(payload['taskId'] as String);

      case 'DENY_TASK':
        pm.deny(payload['taskId'] as String);

      case 'STOP_ALL':
        engine.emergencyStop();

      case 'RUN_WORKFLOW':
        _runWorkflow(payload);
    }
  }

  Future<void> _runWorkflow(Map<String, dynamic> payload) async {
    final rawNodes = payload['nodes'] as List;
    final rawEdges = payload['edges'] as List;
    final taskText = payload['taskText'] as String;

    final nodes = rawNodes.map((n) => BridgeNode(
      id: n['id'] as String,
      name: n['name'] as String,
      kind: NodeKind.values.firstWhere((k) => k.name == (n['kind'] ?? 'agent')),
      detail: n['detail'] as String? ?? '',
      tabId: n['tabId'] as int?,
      url: n['url'] as String?,
    )).toList();

    final edges = rawEdges
        .map((e) => NodeEdge(e['from'] as String, e['to'] as String))
        .toList();

    engine.sendToAdapter = (nodeId, text) {
      final completer = Completer<String?>();
      final taskId = 'ext-${DateTime.now().millisecondsSinceEpoch}';
      _taskCompleters[taskId] = completer;
      _broadcast(jsonEncode({
        'type': 'SEND_TASK',
        'payload': {'nodeId': nodeId, 'taskId': taskId, 'text': text},
      }));
      return completer.future.timeout(const Duration(seconds: 120),
          onTimeout: () => null);
    };

    await engine.run(nodes: nodes, edges: edges, taskText: taskText);
  }

  void _broadcast(dynamic data) {
    final msg = data is String ? data : _eventToJson(data);
    if (msg == null) return;
    for (final ws in List.of(_clients)) {
      try { ws.add(msg); } catch (_) {}
    }
  }

  String? _eventToJson(DaemonEvent event) {
    if (event is LogEntry) {
      return jsonEncode({
        'type': 'LOG_ENTRY',
        'payload': {'message': event.message, 'severity': event.severity},
      });
    }
    if (event is TaskStatusChanged) {
      return jsonEncode({
        'type': 'TASK_STATUS_CHANGED',
        'payload': {'taskId': event.taskId, 'status': event.status.name},
      });
    }
    if (event is ApprovalRequired) {
      return jsonEncode({
        'type': 'APPROVAL_REQUIRED',
        'payload': {
          'taskId': event.task.id,
          'instruction': event.task.instruction,
          'sourceName': event.sourceName,
          'targetName': event.targetName,
        },
      });
    }
    if (event is NodeRegistered) {
      return jsonEncode({
        'type': 'NODE_REGISTERED',
        'payload': {'id': event.node.id, 'name': event.node.name},
      });
    }
    return null;
  }

  Future<void> stop() async {
    for (final ws in _clients) { try { await ws.close(); } catch (_) {} }
    await _server?.close();
  }
}
```

- [ ] **Step 2: Create lib/daemon/daemon.dart**

```dart
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'database.dart';
import 'event_bus.dart';
import 'node_registry.dart';
import 'permission_manager.dart';
import 'task_scheduler.dart';
import 'artifact_store.dart';
import 'workflow_engine.dart';
import 'ws_server.dart';
import 'recovery_manager.dart';

class Daemon {
  static const port = 7432;

  static late SendPort _toMain;
  static late ReceivePort _fromMain;

  // Call from the main isolate
  static Future<({Stream<dynamic> events, SendPort send})> start() async {
    final fromDaemon = ReceivePort();
    final toMain = fromDaemon.sendPort;

    await Isolate.spawn(_daemonMain, toMain);

    // The daemon sends its SendPort as its first message
    final completer = Completer<SendPort>();
    final sub = fromDaemon.listen((msg) {
      if (msg is SendPort) completer.complete(msg);
    });
    final daemonSend = await completer.future;
    sub.cancel();

    return (events: fromDaemon.asBroadcastStream(), send: daemonSend);
  }

  static Future<void> _daemonMain(SendPort toMain) async {
    final fromMain = ReceivePort();
    toMain.send(fromMain.sendPort); // hand shake

    final supportDir = await getApplicationSupportDirectory();
    final db = await BridgeDatabase.open();
    final bus = EventBus();
    final registry = NodeRegistry(db, bus);
    final pm = PermissionManager(db, bus);
    final scheduler = TaskScheduler(db, bus);
    final artifactDir = Directory(
        p.join(supportDir.path, 'BrigadeBridge', 'artifacts'));
    await artifactDir.create(recursive: true);
    final store = ArtifactStore(artifactDir);
    final engine = WorkflowEngine(
      registry: registry,
      scheduler: scheduler,
      permissionManager: pm,
      artifactStore: store,
      bus: bus,
    );
    final recovery = RecoveryManager(db, bus);
    await recovery.replayIncomplete(engine);

    final server = WsServer(
      port: port, bus: bus, engine: engine,
      registry: registry, pm: pm,
    );
    await server.start();

    // Forward bus events to main isolate
    bus.stream.listen((event) => toMain.send(event));

    // Listen for commands from main isolate
    fromMain.listen((msg) {
      if (msg is Map) {
        final type = msg['type'] as String?;
        if (type == 'STOP_ALL') engine.emergencyStop();
        if (type == 'APPROVE_TASK') pm.approve(msg['taskId'] as String);
        if (type == 'DENY_TASK') pm.deny(msg['taskId'] as String);
      }
    });
  }
}
```

- [ ] **Step 3: Create lib/daemon/recovery_manager.dart**

```dart
import 'database.dart';
import 'event_bus.dart';
import 'workflow_engine.dart';

class RecoveryManager {
  RecoveryManager(this._db, this._bus);
  final BridgeDatabase _db;
  final EventBus _bus;

  Future<void> replayIncomplete(WorkflowEngine engine) async {
    final incomplete = await _db.tasks.incompleteTasks();
    if (incomplete.isEmpty) return;
    _bus.publish(LogEntry(
        'Recovered ${incomplete.length} incomplete task(s) from previous session'));
    // Mark them as failed — they will need to be re-run by the user
    for (final t in incomplete) {
      await _db.tasks.updateStatus(t.id, 'failed',
          error: 'Interrupted — app was closed during execution');
    }
  }
}
```

- [ ] **Step 4: Wire Daemon.start() in main.dart**

In `lib/main.dart` update `_AppShellState.initState()`:
```dart
@override
void initState() {
  super.initState();
  BridgeChannel.onHotKeyFired.listen((_) => setState(() {}));
  _startDaemon();
}

Future<void> _startDaemon() async {
  final result = await Daemon.start();
  result.events.listen((event) {
    if (!mounted) return;
    setState(() {
      if (event is LogEntry) {
        _log.insert(0, event.message);
      }
      if (event is NodeRegistered) {
        if (!_nodes.any((n) => n.id == event.node.id)) {
          _nodes.add(event.node);
        }
      }
      if (event is TaskStatusChanged) {
        _status = event.status;
      }
    });
  });
}
```

Add imports at top of `lib/main.dart`:
```dart
import 'daemon/daemon.dart';
import 'daemon/event_bus.dart';
```

- [ ] **Step 5: Build and verify daemon starts**

```bash
flutter build macos --debug && \
open build/macos/Build/Products/Debug/brigade_bridge.app
```
Expected: App opens, activity log shows "Bridge daemon online · Listening on localhost:7432". Use `nc -zv 127.0.0.1 7432` to confirm the port is open.

- [ ] **Step 6: Commit**

```bash
git add lib/daemon/daemon.dart lib/daemon/ws_server.dart \
        lib/daemon/recovery_manager.dart lib/main.dart
git commit -m "feat: Daemon isolate bootstrap, WsServer, RecoveryManager"
```

---

## Phase 3 — Chrome Extension

### Task 11: Extension scaffold + service worker

**Files:**
- Create: `extension/manifest.json`
- Create: `extension/background/service_worker.js`
- Create: `extension/popup/popup.html`
- Create: `extension/popup/popup.css`

**Interfaces:**
- Produces: Chrome extension that connects to `ws://localhost:7432`, sends `REGISTER_TAB` for each open tab, shows connection status in popup

- [ ] **Step 1: Create extension/manifest.json**

```json
{
  "manifest_version": 3,
  "name": "Brigade Bridge",
  "version": "0.1.0",
  "description": "Connect agent tabs to the Brigade Bridge overlay",
  "permissions": ["tabs", "scripting", "storage", "activeTab"],
  "host_permissions": ["<all_urls>"],
  "background": {
    "service_worker": "background/service_worker.js",
    "type": "module"
  },
  "content_scripts": [
    {
      "matches": ["<all_urls>"],
      "js": ["content/bridge_content.js"],
      "run_at": "document_idle"
    }
  ],
  "action": {
    "default_popup": "popup/popup.html",
    "default_title": "Brigade Bridge"
  }
}
```

- [ ] **Step 2: Create extension/background/service_worker.js**

```js
// Brigade Bridge — service worker
// Connects to the local daemon over WebSocket and routes messages.

const DAEMON_URL = 'ws://localhost:7432';
const IDENTITY_MAP = {
  'chatgpt.com/codex': 'Codex',
  'claude.ai': 'Claude',
  'antigravity': 'Anti Gravity',
};

let ws = null;
let connected = false;

function detectIdentity(url) {
  for (const [pattern, name] of Object.entries(IDENTITY_MAP)) {
    if (url.includes(pattern)) return name;
  }
  return null;
}

function send(type, payload) {
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify({ type, id: crypto.randomUUID(), ts: Date.now(), payload }));
  }
}

function connect() {
  ws = new WebSocket(DAEMON_URL);

  ws.onopen = () => {
    connected = true;
    chrome.storage.local.set({ bridgeConnected: true });
    // Register all currently open agent tabs
    chrome.tabs.query({}, (tabs) => {
      for (const tab of tabs) {
        if (!tab.url) continue;
        const identity = detectIdentity(tab.url);
        if (identity) registerTab(tab, identity);
      }
    });
  };

  ws.onclose = () => {
    connected = false;
    chrome.storage.local.set({ bridgeConnected: false });
    setTimeout(connect, 3000); // reconnect
  };

  ws.onmessage = ({ data }) => {
    const msg = JSON.parse(data);
    if (msg.type === 'SEND_TASK') {
      const { nodeId, taskId, text } = msg.payload;
      // Find tab whose id matches nodeId pattern 'tab-{tabId}'
      const tabId = parseInt(nodeId.replace('tab-', ''), 10);
      if (!isNaN(tabId)) {
        chrome.tabs.sendMessage(tabId, { type: 'SEND_TASK', taskId, text });
      }
    }
    if (msg.type === 'CANCEL') {
      const tabId = parseInt(msg.payload.nodeId.replace('tab-', ''), 10);
      if (!isNaN(tabId)) {
        chrome.tabs.sendMessage(tabId, { type: 'CANCEL' });
      }
    }
  };
}

function registerTab(tab, identity) {
  send('REGISTER_TAB', {
    tabId: tab.id,
    url: tab.url,
    title: tab.title,
    identity,
  });
}

// Tab lifecycle
chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  if (changeInfo.status !== 'complete' || !tab.url) return;
  const identity = detectIdentity(tab.url);
  if (identity) registerTab(tab, identity);
});

chrome.tabs.onRemoved.addListener((tabId) => {
  send('TAB_REMOVED', { tabId });
});

// Messages from content scripts
chrome.runtime.onMessage.addListener((msg, sender) => {
  if (msg.type === 'TASK_RESULT' || msg.type === 'ERROR' || msg.type === 'COMPLETION_DETECTED') {
    send(msg.type, { ...msg.payload, tabId: sender.tab?.id });
  }
});

connect();
```

- [ ] **Step 3: Create extension/popup/popup.html**

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>Brigade Bridge</title>
  <link rel="stylesheet" href="popup.css" />
</head>
<body>
  <div class="header">
    <span class="mark">✦</span>
    <strong>Brigade Bridge</strong>
  </div>
  <div id="status" class="status disconnected">● Connecting…</div>
  <script>
    chrome.storage.local.get('bridgeConnected', ({ bridgeConnected }) => {
      const el = document.getElementById('status');
      if (bridgeConnected) {
        el.textContent = '● Connected to daemon';
        el.className = 'status connected';
      } else {
        el.textContent = '● Daemon not found — is Brigade Bridge running?';
      }
    });
  </script>
</body>
</html>
```

- [ ] **Step 4: Create extension/popup/popup.css**

```css
body { font-family: system-ui, sans-serif; background: #10131a; color: #cdd6f4;
       width: 260px; padding: 14px; margin: 0; }
.header { display: flex; align-items: center; gap: 8px; margin-bottom: 12px; }
.mark { color: #8da5ff; font-size: 18px; }
.status { font-size: 12px; padding: 8px 10px; border-radius: 6px;
          background: #1a1f29; }
.connected { color: #56d19a; }
.disconnected { color: #f2a65a; }
```

- [ ] **Step 5: Load extension in Chrome and verify**

1. Open `chrome://extensions`
2. Enable Developer mode
3. Click "Load unpacked" → select the `extension/` folder
4. Open Brigade Bridge app (daemon starts on :7432)
5. Open a Claude tab
6. Click the Brigade Bridge extension icon
Expected: popup shows "● Connected to daemon"; activity log in the app shows "Node registered: Claude".

- [ ] **Step 6: Commit**

```bash
git add extension/
git commit -m "feat: Chrome extension scaffold, service worker, tab registration"
```

---

### Task 12: Content script + adapter framework

**Files:**
- Create: `extension/content/bridge_content.js`
- Create: `extension/content/adapters/claude.js`
- Create: `extension/content/adapters/codex.js`
- Create: `extension/content/adapters/antigravity.js`

**Interfaces:**
- Produces: content script that receives `SEND_TASK` from service worker, routes to the correct adapter, runs the completion state machine, sends `TASK_RESULT` back

- [ ] **Step 1: Create extension/content/adapters/claude.js**

```js
// Claude adapter — selectors versioned as CLAUDE_V1
const CLAUDE_V1 = {
  composer: 'div[contenteditable="true"][data-placeholder]',
  submitBtn: 'button[aria-label="Send message"], button[data-testid="send-button"]',
  spinner: '[data-testid="streaming-indicator"], .loading-indicator',
  lastResponse: '[data-testid="human-turn"] ~ [data-testid="ai-turn"]:last-of-type, ' +
                '.font-claude-message:last-of-type',
};

export function identify(url) {
  return url.includes('claude.ai');
}

export function getComposer() {
  return document.querySelector(CLAUDE_V1.composer);
}

export function submit(text) {
  const el = getComposer();
  if (!el) throw new Error('CLAUDE_V1: composer not found');
  el.focus();
  // Use execCommand to trigger React's synthetic events
  document.execCommand('insertText', false, text);
  // Give React a tick then click submit
  setTimeout(() => {
    const btn = document.querySelector(CLAUDE_V1.submitBtn);
    if (btn) btn.click();
  }, 80);
}

export function isGenerating() {
  return !!document.querySelector(CLAUDE_V1.spinner);
}

export function getLastResponse() {
  const els = document.querySelectorAll(CLAUDE_V1.lastResponse);
  return els.length ? els[els.length - 1].innerText.trim() : '';
}
```

- [ ] **Step 2: Create extension/content/adapters/codex.js**

```js
// Codex (ChatGPT) adapter — selectors versioned as CODEX_V1
const CODEX_V1 = {
  composer: '#prompt-textarea, textarea[data-id="root"]',
  submitBtn: 'button[data-testid="send-button"], button[aria-label="Send prompt"]',
  spinner: '[data-testid="stop-button"], .result-streaming',
  lastResponse: '[data-message-author-role="assistant"]:last-of-type',
};

export function identify(url) {
  return url.includes('chatgpt.com') || url.includes('openai.com/codex');
}

export function getComposer() {
  return document.querySelector(CODEX_V1.composer);
}

export function submit(text) {
  const el = getComposer();
  if (!el) throw new Error('CODEX_V1: composer not found');
  el.focus();
  document.execCommand('insertText', false, text);
  setTimeout(() => {
    const btn = document.querySelector(CODEX_V1.submitBtn);
    if (btn) btn.click();
  }, 80);
}

export function isGenerating() {
  return !!document.querySelector(CODEX_V1.spinner);
}

export function getLastResponse() {
  const el = document.querySelector(CODEX_V1.lastResponse);
  return el ? el.innerText.trim() : '';
}
```

- [ ] **Step 3: Create extension/content/adapters/antigravity.js**

```js
// Anti Gravity adapter — selectors versioned as AGY_V1
const AGY_V1 = {
  composer: 'textarea[data-testid="chat-input"], .chat-composer textarea',
  submitBtn: 'button[data-testid="send-btn"], button[aria-label="Send"]',
  spinner: '.generating-indicator, [data-testid="loading"]',
  lastResponse: '.assistant-message:last-of-type, [data-role="assistant"]:last-of-type',
};

export function identify(url) {
  return url.includes('antigravity') || url.includes('agy.dev');
}

export function getComposer() {
  return document.querySelector(AGY_V1.composer);
}

export function submit(text) {
  const el = getComposer();
  if (!el) throw new Error('AGY_V1: composer not found');
  el.focus();
  document.execCommand('insertText', false, text);
  setTimeout(() => {
    const btn = document.querySelector(AGY_V1.submitBtn);
    if (btn) btn.click();
  }, 80);
}

export function isGenerating() {
  return !!document.querySelector(AGY_V1.spinner);
}

export function getLastResponse() {
  const el = document.querySelector(AGY_V1.lastResponse);
  return el ? el.innerText.trim() : '';
}
```

- [ ] **Step 4: Create extension/content/bridge_content.js**

```js
// Bridge content script — routes SEND_TASK to the correct adapter,
// runs the completion state machine, sends TASK_RESULT back.

import * as claude from './adapters/claude.js';
import * as codex from './adapters/codex.js';
import * as antigravity from './adapters/antigravity.js';

const ADAPTERS = [claude, codex, antigravity];

function getAdapter() {
  return ADAPTERS.find(a => a.identify(location.href)) ?? null;
}

// State machine
const State = { IDLE: 'idle', COMPOSING: 'composing', SUBMITTED: 'submitted',
                GENERATING: 'generating', STABLE: 'stable', DONE: 'done' };

let state = State.IDLE;
let currentTaskId = null;
let stabilityTimer = null;
let urlAtStart = null;
let cancelled = false;

function guardUrl() {
  if (location.href !== urlAtStart) {
    reportError('Tab navigated away during task');
    return false;
  }
  return true;
}

function reportError(reason) {
  chrome.runtime.sendMessage({ type: 'ERROR', payload: { taskId: currentTaskId, reason } });
  reset();
}

function reset() {
  state = State.IDLE;
  currentTaskId = null;
  urlAtStart = null;
  cancelled = false;
  if (stabilityTimer) { clearTimeout(stabilityTimer); stabilityTimer = null; }
}

function waitForStable(adapter, resolve) {
  if (cancelled || !guardUrl()) return;
  if (adapter.isGenerating()) {
    state = State.GENERATING;
    if (stabilityTimer) clearTimeout(stabilityTimer);
    stabilityTimer = null;
    setTimeout(() => waitForStable(adapter, resolve), 300);
    return;
  }
  // Not generating — start 1.5 s stability window
  if (!stabilityTimer) {
    stabilityTimer = setTimeout(() => {
      if (cancelled || !guardUrl()) return;
      state = State.STABLE;
      const text = adapter.getLastResponse();
      chrome.runtime.sendMessage({
        type: 'TASK_RESULT',
        payload: { taskId: currentTaskId, output: text, status: 'completed' }
      });
      reset();
      resolve();
    }, 1500);
  }
  setTimeout(() => waitForStable(adapter, resolve), 300);
}

chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (msg.type === 'CANCEL') {
    cancelled = true;
    reset();
    sendResponse({ ok: true });
    return;
  }

  if (msg.type === 'SEND_TASK') {
    if (state !== State.IDLE) {
      sendResponse({ ok: false, reason: 'busy' });
      return;
    }

    const adapter = getAdapter();
    if (!adapter) {
      chrome.runtime.sendMessage({
        type: 'ERROR',
        payload: { taskId: msg.taskId, reason: 'No adapter for this URL' }
      });
      sendResponse({ ok: false });
      return;
    }

    const composer = adapter.getComposer();
    if (!composer) {
      chrome.runtime.sendMessage({
        type: 'ADAPTER_HEALTH',
        payload: { health: 'requires_update', reason: 'composer not found' }
      });
      sendResponse({ ok: false });
      return;
    }

    currentTaskId = msg.taskId;
    urlAtStart = location.href;
    state = State.COMPOSING;

    try {
      adapter.submit(msg.text);
      state = State.SUBMITTED;
    } catch (e) {
      reportError(e.message);
      sendResponse({ ok: false });
      return;
    }

    new Promise(resolve => {
      // Give submit a moment then start watching
      setTimeout(() => waitForStable(adapter, resolve), 500);
    });

    sendResponse({ ok: true });
  }
});
```

- [ ] **Step 5: Update manifest.json to use ES module content script**

The content script uses ES module `import`. Chrome content scripts don't support top-level `import` directly. Refactor to inline the adapters — replace imports with direct inclusion.

Update `extension/manifest.json`:
```json
{
  "manifest_version": 3,
  "name": "Brigade Bridge",
  "version": "0.1.0",
  "description": "Connect agent tabs to the Brigade Bridge overlay",
  "permissions": ["tabs", "scripting", "storage", "activeTab"],
  "host_permissions": ["<all_urls>"],
  "background": {
    "service_worker": "background/service_worker.js",
    "type": "module"
  },
  "content_scripts": [
    {
      "matches": ["<all_urls>"],
      "js": [
        "content/adapters/claude.js",
        "content/adapters/codex.js",
        "content/adapters/antigravity.js",
        "content/bridge_content.js"
      ],
      "run_at": "document_idle"
    }
  ],
  "action": {
    "default_popup": "popup/popup.html",
    "default_title": "Brigade Bridge"
  }
}
```

Convert adapter files to non-module scripts (remove `export` keywords; expose via `window.BrigadeAdapters`). Update `bridge_content.js` accordingly:

In each adapter, replace `export function` with direct `window` assignment at the bottom:
```js
// At the bottom of each adapter file, e.g. claude.js:
window.BrigadeAdapters = window.BrigadeAdapters || {};
window.BrigadeAdapters.claude = { identify, getComposer, submit, isGenerating, getLastResponse };
```

In `bridge_content.js`, replace `import` with:
```js
const ADAPTERS = Object.values(window.BrigadeAdapters || {});
```

- [ ] **Step 6: Reload extension and test end-to-end with a Claude tab**

1. Reload the extension in `chrome://extensions`
2. Open a Claude tab (`claude.ai`)
3. Open the Brigade Bridge overlay
4. Verify Claude appears as a node in the HUD
5. In the expanded editor, type a short task and dispatch
6. Verify approval modal appears
7. Approve → verify Claude receives the text and sends a response
8. Verify activity log shows task completion

- [ ] **Step 7: Commit**

```bash
git add extension/content/
git commit -m "feat: content script, Claude/Codex/AntiGravity adapters, completion state machine"
```

---

## Phase 4 — Integration & First Milestone

### Task 13: Approval gate wired end-to-end

**Files:**
- Modify: `lib/main.dart` — listen for `ApprovalRequired` events and show `ApprovalModal`

**Interfaces:**
- Consumes: `ApprovalRequired` from daemon event stream, `ApprovalModal.show()`, `Daemon` send port

- [ ] **Step 1: Handle ApprovalRequired in _AppShellState**

In `lib/main.dart`, inside the `result.events.listen` callback, add:

```dart
if (event is ApprovalRequired) {
  if (!mounted) return;
  final decision = await ApprovalModal.show(
    context,
    task: event.task,
    sourceName: event.sourceName,
    targetName: event.targetName,
  );
  switch (decision) {
    case ApprovalDecision.approveOnce:
    case ApprovalDecision.alwaysAllow:
      _daemonSend?.send({'type': 'APPROVE_TASK', 'taskId': event.task.id});
    case ApprovalDecision.deny:
    case ApprovalDecision.denyAll:
      _daemonSend?.send({'type': 'DENY_TASK', 'taskId': event.task.id});
    case null:
      _daemonSend?.send({'type': 'DENY_TASK', 'taskId': event.task.id});
  }
}
```

Add `SendPort? _daemonSend;` as a field, and capture it in `_startDaemon`:
```dart
Future<void> _startDaemon() async {
  final result = await Daemon.start();
  _daemonSend = result.send;
  result.events.listen((event) { /* ... */ });
}
```

Add import:
```dart
import 'ui/approval_modal.dart';
```

- [ ] **Step 2: Wire Run / Stop buttons to daemon**

In `_AppShellState`, update `onRun` and `onStop`:
```dart
onRun: () {
  _daemonSend?.send({
    'type': 'RUN_WORKFLOW',
    'taskText': _log.isNotEmpty ? _log.first : 'Run workflow',
    'nodes': _nodes.map((n) => {
      'id': n.id, 'name': n.name,
      'kind': n.kind.name, 'detail': n.detail,
      'tabId': n.tabId, 'url': n.url,
    }).toList(),
    'edges': _edges.map((e) => {'from': e.from, 'to': e.to}).toList(),
  });
},
onStop: () {
  _daemonSend?.send({'type': 'STOP_ALL'});
  setState(() { _status = TaskStatus.stopped; });
},
```

- [ ] **Step 3: Build and run full milestone test**

Run through the milestone scenario manually:
1. Launch app → ✦ appears in menu bar, no Dock icon
2. Press ⌥Space → compact HUD appears
3. Open Codex, Claude, Anti Gravity tabs in Chrome
4. Extension registers all three → HUD shows three node chips
5. Click Expand → click Codex, then Claude → edge drawn
6. Click Claude, then Anti Gravity → second edge drawn
7. Type task text, click Dispatch
8. Approval modal appears → Approve once
9. Watch Claude receive text and respond
10. Activity log shows TASK_RESULT entries
11. Press ⌥Space → overlay hides; ✦ stays in menu bar

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: approval gate wired end-to-end, Run/Stop connected to daemon"
```

---

### Task 14: Emergency stop end-to-end + audit log page

**Files:**
- Modify: `lib/ui/expanded_editor.dart` — add Settings tab stub with Audit Log
- Create: `lib/ui/audit_log_page.dart`

**Interfaces:**
- Consumes: `AuditDao.recent()` via a passed list; daemon forwards `STOP_ALL`

- [ ] **Step 1: Create lib/ui/audit_log_page.dart**

```dart
import 'package:flutter/material.dart';
import '../daemon/database.dart';

class AuditLogPage extends StatelessWidget {
  const AuditLogPage({super.key, required this.entries});
  final List<AuditLogData> entries;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff10131a),
      appBar: AppBar(
        title: const Text('Audit Log', style: TextStyle(fontSize: 15)),
        backgroundColor: const Color(0xff141820),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: entries.length,
        itemBuilder: (_, i) {
          final e = entries[i];
          final ts = DateTime.fromMillisecondsSinceEpoch(e.ts);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 8, height: 8, margin: const EdgeInsets.only(top: 4, right: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: e.decision == 'approved' || e.decision == 'auto'
                      ? const Color(0xff56d19a) : const Color(0xffff6b6b),
                ),
              ),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${e.capability} on ${e.nodeId}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text('${e.decision}  ·  task ${e.taskId}',
                    style: const TextStyle(fontSize: 10, color: Color(0xff7d8798))),
                Text('${ts.hour.toString().padLeft(2,'0')}:${ts.minute.toString().padLeft(2,'0')}:${ts.second.toString().padLeft(2,'0')}',
                    style: const TextStyle(fontSize: 9, color: Color(0xff4a5568))),
              ])),
            ]),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Test emergency stop propagation**

Write `test/daemon/emergency_stop_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brigade_bridge/daemon/database.dart';
import 'package:brigade_bridge/daemon/event_bus.dart';
import 'package:brigade_bridge/daemon/node_registry.dart';
import 'package:brigade_bridge/daemon/permission_manager.dart';
import 'package:brigade_bridge/daemon/task_scheduler.dart';
import 'package:brigade_bridge/daemon/artifact_store.dart';
import 'package:brigade_bridge/daemon/workflow_engine.dart';
import 'package:brigade_bridge/core/bridge_models.dart';
import 'package:drift/drift.dart';
import 'dart:io';

void main() {
  test('emergencyStop emits LogEntry with severity=emergency', () async {
    final db = BridgeDatabase(NativeDatabase.memory());
    final bus = EventBus();
    final tmp = await Directory.systemTemp.createTemp();
    final engine = WorkflowEngine(
      registry: NodeRegistry(db, bus),
      scheduler: TaskScheduler(db, bus),
      permissionManager: PermissionManager(db, bus),
      artifactStore: ArtifactStore(tmp),
      bus: bus,
    );

    final events = <DaemonEvent>[];
    bus.stream.listen(events.add);

    engine.emergencyStop();
    await Future.delayed(Duration.zero);

    final emergencyLogs = events
        .whereType<LogEntry>()
        .where((e) => e.severity == 'emergency')
        .toList();
    expect(emergencyLogs.length, 1);

    await db.close();
    bus.dispose();
    await tmp.delete(recursive: true);
  });
}
```

- [ ] **Step 3: Run test**

```bash
flutter test test/daemon/emergency_stop_test.dart
```
Expected: PASS (1 test).

- [ ] **Step 4: Run all tests**

```bash
flutter test
```
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/audit_log_page.dart test/daemon/emergency_stop_test.dart
git commit -m "feat: AuditLogPage, emergency stop test, all tests passing"
```

---

## Verification Plan

### Run all automated tests

```bash
cd "/Users/anaslari/Downloads/brigade bridge"
flutter test
```
Expected: All green.

### Build release binary

```bash
flutter build macos
```
Expected: Build succeeds with no errors.

### Manual milestone walkthrough checklist

- [ ] No Dock icon after launch
- [ ] ✦ appears in menu bar
- [ ] ⌥Space shows compact HUD (or clicking ✦)
- [ ] Opening Codex / Claude / Anti Gravity tabs registers them as nodes
- [ ] Node chips appear in HUD within 2 s
- [ ] Expand button transitions to full editor (animated)
- [ ] Clicking node, then another node draws an SVG edge
- [ ] Dispatch task → approval modal appears
- [ ] Approve once → text appears in agent tab
- [ ] Response extracted → activity log entry
- [ ] Second node in chain receives first node's output
- [ ] Third node receives second node's output
- [ ] Emergency Stop → all tasks cancelled, badge turns red
- [ ] ⌥Space hides overlay; daemon still listening on :7432
- [ ] Re-opening overlay → nodes still visible
