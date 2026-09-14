# Brigade Bridge — Design Specification

**Date:** 2026-09-14  
**Status:** Approved — ready for implementation planning  
**Approach:** A — Incremental layers (overlay shell → daemon → Chrome extension → adapters)

---

## 1. Problem and Goal

Brigade Bridge is a local macOS overlay that lets a user visually connect AI agent browser tabs and desktop applications, delegate tasks between them through their existing logged-in sessions, and maintain full control via an approval gate — without any remote server, API keys, or credential extraction.

The first meaningful release proves this workflow:

```
⌥Space → overlay appears
→ Codex tab, Claude tab, Anti Gravity tab visible as nodes
→ user draws edges: Codex → Claude → Anti Gravity
→ types a task, presses Run
→ daemon dispatches through existing sessions
→ approval gate shown before any text is injected
→ result returned, artifacts stored
→ ⌥Space → overlay hides; daemon keeps running
```

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│  macOS NSPanel (Flutter overlay)                    │
│  Menu-bar status item  ·  ⌥Space global shortcut   │
│  Compact HUD  ↔  Expanded workflow editor           │
│  Node canvas · Activity log · Approval gate         │
└─────────────────┬───────────────────────────────────┘
                  │  Dart FFI / method channel
┌─────────────────▼───────────────────────────────────┐
│  Daemon — Dart Isolate (ws://localhost:7432)         │
│  node_registry  ·  task_scheduler                   │
│  workflow_engine ·  adapter_manager                 │
│  permission_manager · event_bus                     │
│  artifact_store  ·  recovery_manager                │
│  SQLite (drift)  ·  JSON-over-WebSocket             │
└──────┬──────────────────────────────────────────────┘
       │  WebSocket  ws://localhost:7432
┌──────▼──────────────────────────────────────────────┐
│  Chrome Extension (Manifest V3)                     │
│  background service-worker ↔ content scripts        │
│  Adapters: Codex · Claude · Anti Gravity            │
└─────────────────────────────────────────────────────┘
```

### Key technology decisions

| Concern | Choice | Reason |
|---|---|---|
| UI | Flutter macOS | Native NSPanel via method channel |
| Daemon | Dart Isolate (same process) | Single binary, no install |
| IPC | WebSocket JSON on localhost:7432 | Extension can connect natively |
| Persistence | SQLite via drift | Local, typed, no server |
| Extension | Chrome Manifest V3 | Current platform requirement |
| Overlay default | Compact HUD + expand-on-demand | Does not steal the screen |

---

## 3. macOS Overlay Shell

### Application identity

- LSUIElement = YES in Info.plist — no Dock icon, no app switcher
- NSPanel window class — floats above normal windows
- NSPanel.level = .floating
- NSPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

### Swift method channel — BridgeChannel

Registered on the Flutter engine at startup. Exposes:

```swift
showPanel()
hidePanel()
registerHotKey(keyCode: Int, modifiers: Int)
setStatusItemBadge(state: String)   // idle | running | waiting | stopped
requestAccessibilityPermission()
```

### Menu-bar status item

- Glyph: ✦
- Left-click: toggle compact HUD
- Right-click menu: Show, Settings, Quit
- Badge colour: green (idle), amber (running / waiting), red (stopped)

### Overlay modes

Compact HUD — 280 × 420 pt, anchored near menu bar.
Shows node chips with status dots, one-line event tail, Run / Stop buttons, Expand button.

Expanded editor — 820 × 580 pt, centred.
Three-column layout: sidebar (node palette + workflow name), canvas (SVG edge graph), inspector (activity log + task input + permissions).

Transition: animated window resize + crossfade, 200 ms.

### Global shortcut

⌥Space registered via hotkey Flutter package, forwarded through BridgeChannel.
If panel hidden: shows it. If visible: hides it.

### Other behaviours

| Feature | Implementation |
|---|---|
| Launch at login | SMAppService.mainApp.register() (macOS 13+) |
| Hide without quit | Panel close() — isolate stays alive |
| Multi-Space | .canJoinAllSpaces collection behaviour |
| Full-screen passthrough | .fullScreenAuxiliary |

---

## 4. Local Daemon (Dart Isolate)

### Modules

```
daemon/
├── node_registry.dart       discovers, tracks, health-checks nodes
├── task_scheduler.dart      queues and dispatches tasks
├── workflow_engine.dart     steps through node graphs sequentially
├── adapter_manager.dart     owns adapter instances, routes commands
├── permission_manager.dart  per-node, per-workflow capability rules
├── event_bus.dart           in-process Dart Stream pub/sub
├── artifact_store.dart      stores text/file artifacts with metadata
└── recovery_manager.dart    replays failed tasks on crash restart
```

### WebSocket protocol — message envelope

```json
{
  "type": "MESSAGE_TYPE",
  "id":   "uuid-v4",
  "ts":   1726312000000,
  "payload": {}
}
```

### UI → Daemon commands

| type | payload |
|---|---|
| RUN_WORKFLOW | {workflowId, nodes, edges, taskText} |
| APPROVE_TASK | {taskId} |
| DENY_TASK | {taskId} |
| STOP_ALL | {} |
| LIST_NODES | {} |

### Daemon → UI events

| type | meaning |
|---|---|
| NODE_REGISTERED | new node available |
| TASK_STATUS_CHANGED | task state transition |
| APPROVAL_REQUIRED | overlay must show gate |
| ADAPTER_HEALTH | healthy / degraded / unavailable / requires_update |
| LOG_ENTRY | append to activity log |
| NODE_LIST | response to LIST_NODES |

### Extension → Daemon messages

| type | payload |
|---|---|
| REGISTER_TAB | {tabId, url, title, identity} |
| TASK_RESULT | {taskId, output, status} |
| COMPLETION_DETECTED | {tabId, taskId} |
| ERROR | {taskId, reason} |

### Daemon → Extension commands

| type | payload |
|---|---|
| SEND_TASK | {tabId, taskId, text} |
| CANCEL | {tabId} |

### SQLite schema (drift)

```sql
CREATE TABLE nodes (
  id TEXT PRIMARY KEY,
  name TEXT, kind TEXT, url TEXT, tab_id INTEGER,
  permission_tier TEXT DEFAULT 'read_only',
  health TEXT DEFAULT 'healthy',
  created_at INTEGER
);

CREATE TABLE workflows (
  id TEXT PRIMARY KEY,
  name TEXT, graph_json TEXT, created_at INTEGER
);

CREATE TABLE tasks (
  id TEXT PRIMARY KEY,
  workflow_id TEXT, source_node TEXT, target_node TEXT,
  instruction TEXT, status TEXT, result TEXT, error TEXT,
  created_at INTEGER, updated_at INTEGER
);

CREATE TABLE audit_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts INTEGER, node_id TEXT, capability TEXT,
  decision TEXT, task_id TEXT
);
```

### Task status state machine

```
created → queued → working → waiting_for_approval → completed
                           ↘ failed
                           ↘ cancelled
```

### Daemon lifecycle

```
App launch
  → spawn Dart isolate
  → open WebSocket server on localhost:7432
  → recovery_manager checks for interrupted tasks and replays

Chrome extension connects
  → sends REGISTER_TAB for each known agent tab
  → node_registry adds nodes

User triggers RUN_WORKFLOW
  → workflow_engine steps through edges sequentially
  → permission check before each task
  → if approval needed: emit APPROVAL_REQUIRED, pause
  → on APPROVE_TASK: resume
  → artifact_store saves each node's output

App hides
  → isolate continues, status item badge reflects state

App quits
  → graceful shutdown: flush DB, close WS connections
```

---

## 5. Chrome Extension

### Directory structure

```
extension/
├── manifest.json
├── background/
│   └── service_worker.js     WebSocket client to daemon
├── content/
│   ├── bridge_content.js     injected into every tab
│   └── adapters/
│       ├── codex.js
│       ├── claude.js
│       └── antigravity.js
└── popup/
    └── popup.html            connection status indicator
```

### manifest.json key permissions

```json
{
  "manifest_version": 3,
  "permissions": ["tabs", "scripting", "storage"],
  "host_permissions": ["ws://localhost:7432/*", "<all_urls>"],
  "background": { "service_worker": "background/service_worker.js" },
  "content_scripts": [{
    "matches": ["<all_urls>"],
    "js": ["content/bridge_content.js"],
    "run_at": "document_idle"
  }]
}
```

### Per-adapter interface

Every adapter exports exactly:

```js
identify(url)       // → bool
getComposer()       // → Element | null
submit(text)        // → void
isGenerating()      // → bool
getLastResponse()   // → string
```

Selectors are versioned constants (CODEX_V1, CLAUDE_V2, AGY_V1). If any selector returns null, the adapter emits ADAPTER_HEALTH: requires_update and the workflow pauses.

### Completion state machine (per content script)

```
idle → composing → submitted → generating → stable → done
                                            (MutationObserver quiet 1.5s
                                             AND no spinner in DOM)
```

### Safety invariants

- identify(url) checked before every action; stops if tab navigated away
- Never reads or writes cookies, localStorage, or session storage
- Submits only text passed from the daemon
- Unexpected DOM structure → requires_update health, workflow halts

---

## 6. Security and Permissions

### Permission tiers

| Tier | Capabilities | Default |
|---|---|---|
| read_only | read_text, read_screen | Auto-granted |
| input | send_text, click | Approval required |
| file | upload_file, download_file | Allowlist + approval |
| system | run_command, open_link | Always explicit grant |

All new nodes start at read_only.

### Approval gate UI

Shown as Flutter modal before any action above read_only:

```
⚠  Approval required

Claude wants to send text to Codex
Task: "Review the current project structure…"

[Deny]              [Deny all in workflow]
[Approve once]      [Always allow]
```

"Always allow" writes a persistent rule to SQLite.
"Deny all" sets all pending tasks to cancelled.

### Data never stored

- Cookies, session tokens, passwords
- Full page HTML (only adapter-extracted text)
- Anything not explicitly produced by a task

### Emergency stop

A global StopSignal (Completer<void>) checked at every:
- Workflow engine step boundary
- Adapter state machine transition
- WebSocket message dispatch loop

On trigger: all tasks → cancelled, content scripts receive CANCEL,
status item turns red, audit log entry written.

### Audit log

Every permission decision written to audit_log table:
{ts, node_id, capability, decision (approved|denied|auto), task_id}

Readable from Settings → Audit log in the overlay.

---

## 7. Artifacts and Shared Context

### What nodes can exchange

- Plain text
- URLs
- Screenshots (PNG, stored as file path)
- JSON blobs
- Code patches

### Storage format

```
~/Library/Application Support/BrigadeBridge/artifacts/
└── {task_id}/
    ├── output.txt     (or .json / .png)
    └── meta.json      {sourceNode, ts, taskId, contentHash, permissionTier}
```

---

## 8. End-to-End Milestone Data Flow

```
User presses ⌥Space
  → BridgeChannel fires hotkey_fired
  → Flutter shows compact HUD (NSPanel.floating)

Extension service worker (running since app launch)
  → has sent REGISTER_TAB for Codex, Claude, Anti Gravity tabs
  → daemon node_registry holds three nodes (all read_only)

Flutter HUD shows three node chips
  → user taps Codex, taps Claude  →  edge Codex → Claude
  → user taps Claude, taps AntiGravity  →  edge Claude → AntiGravity
  → types task text, presses Run

UI sends RUN_WORKFLOW
  → workflow_engine: step to node 1 (Codex)
  → permission_manager: send_text needed, tier=read_only → PAUSE
  → daemon emits APPROVAL_REQUIRED

Flutter shows approval modal
  → user taps "Approve once"
  → daemon receives APPROVE_TASK, resumes

adapter_manager sends SEND_TASK {tabId, text}
  → service worker → codex.js content script
  → getComposer() → types text → submit()
  → state: submitted → generating → stable (1.5s quiet)
  → getLastResponse() → artifact stored
  → TASK_RESULT → daemon → task = completed

workflow_engine: step to node 2 (Claude)
  → injects Codex output as task text
  → same approval + injection + extraction flow

workflow_engine: step to node 3 (Anti Gravity)
  → same flow; final artifact stored

daemon emits TASK_STATUS_CHANGED(completed) × 3
  → Flutter activity log shows full event stream

User presses ⌥Space
  → panel hides; isolate running; status item ✦ green (idle)
```

---

## 9. Implementation Order (Approach A — five phases)

```
Phase 1 — macOS overlay shell
  1a. Flutter app: LSUIElement, NSPanel, BridgeChannel Swift code
  1b. Menu-bar status item + badge states
  1c. ⌥Space hotkey via method channel
  1d. Compact HUD widget
  1e. Expanded editor widget (sidebar + canvas + inspector)
  1f. Animated mode transition

Phase 2 — Daemon (Dart Isolate)
  2a. Isolate bootstrap, WebSocket server on :7432
  2b. drift SQLite schema and DAOs
  2c. node_registry, event_bus
  2d. permission_manager (tiers + approval gate)
  2e. task_scheduler, workflow_engine (sequential)
  2f. artifact_store
  2g. recovery_manager (crash replay)
  2h. Flutter ↔ daemon message wiring (UI streams)

Phase 3 — Chrome extension
  3a. manifest.json + service_worker.js skeleton
  3b. Tab registration (REGISTER_TAB flow)
  3c. bridge_content.js routing
  3d. codex.js adapter
  3e. claude.js adapter
  3f. antigravity.js adapter
  3g. Popup status UI

Phase 4 — Integration and first milestone
  4a. Approval gate modal in Flutter
  4b. Emergency stop wiring (StopSignal end-to-end)
  4c. Activity log live stream
  4d. Audit log Settings page
  4e. End-to-end milestone test (simulated → real adapters)

Phase 5 — Polish and packaging
  5a. Launch-at-login (SMAppService)
  5b. First-run setup (accessibility permission prompt)
  5c. .app build, code signing
  5d. .dmg packaging + update mechanism
```

---

## 10. Verification Plan

### Automated (unit + integration)

- Daemon protocol: send each command type, assert emitted events
- Permission manager: assert tier promotion requires approval
- Workflow engine: sequential graph with mock adapters
- Adapter contract: each adapter against fixture HTML snapshots
- Recovery manager: simulate crash mid-task, assert replay

### Safety-critical manual tests

| Scenario | Expected outcome |
|---|---|
| Tab navigates away during task | Adapter detects URL change, emits ERROR, workflow pauses |
| App closes mid-task | Recovery manager replays on next launch |
| Emergency stop during generation | All tasks cancelled; content script receives CANCEL |
| Approval denied | Task marked cancelled, no text injected |
| DOM selector breaks | Adapter emits requires_update, workflow pauses |
| Duplicate RUN_WORKFLOW while running | task_scheduler rejects second run |
| Accessibility permission denied at OS | requestAccessibilityPermission modal shown |
