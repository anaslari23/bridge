# Explicit App Collaboration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn Brigade Bridge into an explicit-connection HUD that routes commands to one connected app and relays only the subtasks that app chooses to delegate.

**Architecture:** Keep the Flutter HUD and local Dart daemon, but make app connectors the only route into connected apps. A locally paired Chrome extension is the first connector; other named apps must use an explicit, validated connector supported by that app. The daemon owns task routing, project-scoped approval decisions, and handoff correlation; the graph remains visual only.

**Tech Stack:** Flutter/Dart 3, Drift/SQLite, local loopback WebSocket, Chrome Manifest V3, JavaScript, existing Flutter and Node test suites.

**Spec:** `docs/superpowers/specs/2026-10-14-explicit-app-bridge-design.md`

## Global Constraints

- No provider API keys or separate paid model environment.
- No Bridge-created workspace, agent runtime, or project copy.
- No launching, scanning, or controlling applications that the user has not explicitly connected.
- No direct app-to-app network channel. Bridge is the relay between connectors.
- The node graph is a visual map. Its lines do not grant, deny, or constrain delegation paths.
- Connecting an app permits task and response exchange through its connector; it does not automatically approve sensitive actions.
- Bridge passes the project identifier with task and handoff messages but does not create or mount a separate project environment.
- An app's own confirmation and safety controls remain in effect. Bridge approval does not bypass them.

## Review Focus

- **Unconnected browser tabs:** They must not be injected, enumerated for content, registered, or receive tasks. Pin this in connector popup and server registration tests (Task 1).
- **Connector loss during a task:** Mark the app unavailable and fail/report the current task; never silently reroute it. Pin this in WebSocket integration tests (Task 1 and Task 4).
- **Project permission leakage:** A grant for one project, app, or capability must not authorize another. Pin all three scopes in permission tests (Task 2).
- **Invalid or recursive delegation:** Reject self-delegation, unknown nodes, unsupported capabilities, stale correlation IDs, and excessive handoff depth. Pin these cases in delegation tests (Task 4).
- **Graph edges treated as policy:** A task must route to its chosen lead regardless of absent, reversed, or unrelated display edges. Pin this in routing tests (Task 3).

---

## File map

- `lib/core/bridge_models.dart` — shared node, project, task, approval, and handoff data.
- `lib/core/bridge_protocol.dart` (new) — typed connector messages and strict delegation directive parser.
- `lib/daemon/database.dart` and generated `database.g.dart` — project contexts and project-scoped approval grants.
- `lib/daemon/node_registry.dart` — only explicitly paired nodes are eligible; persist connector identity and capabilities.
- `lib/daemon/ws_server.dart` — authenticated connector protocol, single-lead dispatch, task results, handoffs, approvals, and browser research.
- `lib/daemon/daemon.dart` — remove automatic local/desktop discovery and wire the coordinator to user-owned connections.
- `lib/daemon/permission_manager.dart` — one-time and project-scoped action approval.
- `lib/daemon/event_bus.dart` — approval request IDs and parent/child task event metadata.
- `lib/daemon/workflow_engine.dart` and `task_scheduler.dart` — route a lead task and track delegated child tasks/cancellation.
- `lib/daemon/project_store.dart` (new) — create/list/select named project contexts without opening or inspecting project files.
- `lib/daemon/lead_router.dart` (new) — choose one connected lead using connector-declared task domains and availability, or honor a per-command override.
- `lib/daemon/delegation_manager.dart` (new) — validate and correlate requested subtasks and relay results to the requesting app.
- `lib/main.dart` — translate HUD actions and daemon events for selected project, lead, approvals, and handoffs.
- `lib/ui/expanded_editor.dart`, `node_canvas.dart`, `overlay_shell.dart`, and `activity_inspector.dart` — project/lead selection, connected-app visualization, handoff timeline, and stop control.
- `lib/ui/approval_modal.dart` — action-specific prompt with **Allow** and **Always allow for this project**.
- `test/daemon/ws_server_desktop_test.dart` — regression coverage that system-wide desktop actions cannot bypass explicit app connectors.
- `chrome-extension/manifest.json`, `background.js`, `content.js`, and new `popup.html`, `popup.js`, `popup.css` — user-initiated connect/disconnect for the active tab only, no all-tab scanning.
- `test/core`, `test/daemon`, `test/ui`, and `test/connector` — model, protocol, persistence, routing, approval, and UI behavior tests.

## Connector compatibility gate

The first code deliverable is a compatibility check for the named apps. An app
has a viable ingress when a user-initiated connector can address an already
running session through a documented local CLI, IPC, or server interface and
return its result. An app's ability to call an MCP tool alone is not enough to
prove that Bridge can start a task in that app. Do not launch apps, start
servers, or discover sessions implicitly; the user must explicitly connect an
already-running session. Do not substitute macOS-wide accessibility control.

Validate the supported setup route for Claude Desktop, Antigravity, OpenCode,
Codex, and browser-based Claude/ChatGPT/Codex. Record which supports existing
session task delivery, results, delegation requests, cancellation, and approval
events. Relevant vendor documentation includes [Claude Desktop local
extensions](https://support.anthropic.com/en/articles/10949351-getting-started-with-local-mcp-servers-on-claude-desktop),
[Antigravity MCP](https://antigravity.google/docs/ide-mcp), [OpenCode
MCP](https://docs.opencode.ai/docs/mcp-servers/), and [OpenAI MCP
plugins](https://developers.openai.com/plugins/build/mcp-server). If a named
app has no supported explicit bidirectional path, keep it unavailable and
return to the user with the compatibility result before implementing a
workaround.

### Task 1: Explicit connector lifecycle and compatibility gate

**Files:**
- Modify: `chrome-extension/manifest.json`
- Modify: `chrome-extension/background.js`
- Modify: `chrome-extension/content.js`
- Create: `chrome-extension/popup.html`
- Create: `chrome-extension/popup.js`
- Create: `chrome-extension/popup.css`
- Modify: `lib/daemon/ws_server.dart`
- Modify: `lib/daemon/node_registry.dart`
- Modify: `lib/daemon/daemon.dart`
- Modify: `lib/main.dart`
- Modify: `lib/ui/expanded_editor.dart`
- Test: `test/connector/content_protocol_test.js`
- Modify: `test/daemon/ws_server_desktop_test.dart`
- Test: `test/daemon/ws_server_integration_test.dart`
- Test: `test/daemon/node_registry_test.dart`

**Interfaces:**
- Consumes: Existing `BridgeNode`, `NodeRegistry.register(BridgeNode)`, and authenticated `WsServer` protocol.
- Produces: `CONNECT_ACTIVE_TAB` and `DISCONNECT_TAB` user gestures in the extension; authenticated `REGISTER_TAB`/`TAB_REMOVED` protocol messages; `NodeRegistry.connectedNodes()` and `Future<void> remove(String nodeId)` for currently paired nodes only.

- [x] **Step 1: Add connector compatibility cases** to `test/connector/content_protocol_test.js` and a new `test/connector/explicit_connection_test.js`. Assert a tab is not registered before the user clicks Connect, only the active tab is paired after the click, and Disconnect sends `TAB_REMOVED`.
- [x] **Step 2: Run the connector tests and confirm the new cases fail.** Run: `node test/connector/content_protocol_test.js && node test/connector/explicit_connection_test.js`. Expected: the unmodified service worker still registers tabs without an explicit click.
- [x] **Step 3: Replace all-tab injection with active-tab pairing.** Remove `<all_urls>` content script injection and all-tab startup enumeration from the manifest/service worker. Add popup actions that inject `content.js` into only the active tab after a user click, persist only user-selected tab IDs, restore only those selected tabs after extension restart, and send `TAB_REMOVED` on disconnect.
- [x] **Step 4: Enforce explicit registration on the daemon.** In `WsServer`, bind a registered tab to the authenticated socket and accept removal only from that socket. Add `NodeRegistry.connectedNodes()` and `remove(String nodeId)`; ensure disconnected nodes are unavailable for routing and cannot be restored as connected from stale database rows.
- [x] **Step 5: Remove implicit OS node access.** Stop auto-discovering terminal/file nodes in daemon startup and directory changes, and stop registering desktop windows from `main.dart`. Update `test/daemon/ws_server_desktop_test.dart` so desktop actions cannot bypass an explicit connector. Remove or relabel UI settings that promise global app discovery/control. Keep unrelated file chooser behavior only if it is user-invoked and not exposed as a connected node.
- [x] **Step 6: Add protocol and registry regression tests.** Verify unauthenticated registration is rejected, another socket cannot remove a node it does not own, disconnected nodes are not returned by `connectedNodes()`, and unpaired tabs never appear in `NodeRegistered` events.
- [x] **Step 7: Run connector and daemon tests.** Run: `node test/connector/content_protocol_test.js && node test/connector/explicit_connection_test.js && flutter test test/daemon/ws_server_integration_test.dart test/daemon/node_registry_test.dart`. Expected: all pass.
- [x] **Step 8: Complete the compatibility matrix.** The installed OpenCode CLI (1.18.14) advertises `run --session` and `run --attach`; its documented local server accepts messages for an existing session and can abort work. The installed Codex CLI (0.162.1) advertises session resume and an app-server proxy to a running server socket; the documented protocol supports thread resume, turn start, events, and interruption. Antigravity's official CLI documentation describes headless prompt input and resuming an existing conversation, but no `agy` executable is installed here, so this is not verified against the native IDE. OpenCode/Codex are native ingress candidates only when the user explicitly pairs an already-running server/session. No native Bridge connectors are implemented yet. Claude and Antigravity native bundle analysis could not complete because REA's Swift helper was blocked writing under `~/.cache/clang`; classify native GUI ingress as unknown, not absent. A manually paired Chrome tab remains the implemented connector.

| App/session | HUD task input | Result | Delegate | Cancel | Bridge approval |
|---|---:|---:|---:|---:|---:|
| Claude Desktop | Unknown; bundle analysis blocked | Unknown | Unknown | Unknown | Unknown |
| Antigravity native IDE | Unknown; bundle analysis blocked | Unknown | Unknown | Unknown | Unknown |
| Antigravity CLI | Documented `-p` and existing-conversation flags; CLI not installed locally | Documented response output | Not verified | CLI session stop controls | Not verified |
| OpenCode 1.18.14 local session/server | Yes, CLI/server | Yes | Not verified | API abort documented | Not verified |
| Codex CLI/app-server session | Yes, CLI/app-server | Yes | Protocol supports agents; Bridge relay unverified | Interruption supported | Approval events supported |
| User-paired Claude/ChatGPT/Codex browser tab | Yes | Yes | Yes, strict response marker | Yes | Yes, project-scoped |

### Task 2: Active project contexts and scoped approvals

**Files:**
- Modify: `lib/core/bridge_models.dart`
- Modify: `lib/daemon/database.dart`
- Regenerate: `lib/daemon/database.g.dart`
- Create: `lib/daemon/project_store.dart`
- Modify: `lib/daemon/permission_manager.dart`
- Modify: `lib/daemon/event_bus.dart`
- Modify: `lib/daemon/daemon.dart`
- Modify: `lib/main.dart`
- Modify: `test/daemon/database_test.dart`
- Modify: `test/daemon/permission_manager_test.dart`
- Create: `test/daemon/project_store_test.dart`
- Modify: `test/daemon/permission_manager_test.dart`

**Interfaces:**
- Consumes: Task 1's authenticated connection identity and current `SettingsDao`/Drift patterns.
- Produces: `ProjectContext({required String id, required String name})`; `ProjectStore.list()`, `create({required String id, required String name})`, `rename(String id, String name)`, and `setActive(String projectId)`; `BridgeTask.projectId`; `PermissionManager.checkAndRequest({required String approvalId, required String nodeId, required String capability, required BridgeTask task, required String projectId, String? preview}) -> Future<bool>`; `PermissionManager.allowForProject({required String approvalId, required String nodeId, required String capability, required String projectId})`.

- [x] **Step 1: Add persistence tests** for project create/list/rename, current-project restoration, and grants keyed by `(projectId, nodeId, capability)`. Add cases proving a grant does not cross projects, apps, or capabilities, and two pending approval IDs for the same task remain independent.
- [x] **Step 2: Run the new tests and confirm they fail.** The initial red run failed on the absent store and approval APIs.
- [x] **Step 3: Add project and grant Drift tables** and bump the schema version to 3. Add nullable project/task-parent metadata and default-zero handoff depth. Legacy `BridgeTask` constructors retain a `project-default` fallback for existing internal/test callers; HUD dispatches carry the selected project ID.
- [x] **Step 4: Implement `ProjectStore`** with create/list/rename/select and startup restoration. Workflow submissions reject unknown project IDs in the daemon.
- [x] **Step 5: Replace global node permission tiers with project-scoped grants.** Pending prompts use `approvalId`; `allowForProject` saves and resolves only the matching project/app/capability request. Legacy node-wide tiers are not promoted into grants.
- [x] **Step 6: Add migration and grant isolation tests.** Verify v2 task migration preserves rows, project/app/capability scopes are isolated, and legacy permission tiers do not silently become grants.
- [x] **Step 7: Run persistence and permission tests.** The focused database, project, permission, task scheduler, and unknown-project tests passed serially.

### Task 3: Lead selection and single-app dispatch

**Files:**
- Modify: `lib/core/bridge_models.dart`
- Create: `lib/daemon/lead_router.dart`
- Modify: `lib/daemon/workflow_engine.dart`
- Modify: `lib/daemon/ws_server.dart`
- Modify: `lib/daemon/daemon.dart`
- Modify: `lib/main.dart`
- Create: `test/core/lead_router_test.dart`
- Modify: `test/daemon/workflow_engine_test.dart`
- Modify: `test/daemon/ws_server_integration_test.dart`

**Interfaces:**
- Consumes: Task 1's `connectedNodes()` and Task 2's required project context.
- Produces: `BridgeNode.taskDomains`; `TaskDomainClassifier.classify(String taskText) -> Set<String>`; `LeadRouter.selectLead({required String taskText, required List<BridgeNode> connectedNodes, String? overrideNodeId}) -> BridgeNode?`; `WorkflowEngine.run({required String taskText, required String projectId, required List<BridgeNode> nodes, String? targetNodeId, String? workflowId})` dispatches only to the selected lead.

- [x] **Step 1: Add `test/core/lead_router_test.dart`** for classifier mapping, domain matching, unavailable nodes, valid/invalid overrides, and no eligible node; add single-lead workflow coverage.
- [x] **Step 2: Run the tests and confirm they fail.** Initial red run failed because the router and task-domain API did not exist.
- [x] **Step 3: Define connector task domains** on `BridgeNode` and browser registration metadata; keep `capabilities` for protocol operations.
- [x] **Step 4: Implement `TaskDomainClassifier.classify` and `LeadRouter.selectLead`.** Deterministic local categories use connector-declared domains; only connected `receive_task` nodes qualify; valid overrides win and invalid overrides return null.
- [x] **Step 5: Change `WorkflowEngine.run` to dispatch one lead.** The daemon selects from live registered nodes and passes one lead; graph edges no longer select or gate the route.
- [x] **Step 6: Add edge-independence and override tests.** An explicit target dispatches only that node regardless of reversed display edges; router tests cover overrides.
- [x] **Step 7: Run routing and workflow tests.** Focused router, workflow, registry, WebSocket, and connector tests passed serially.

### Task 4: Delegation relay, correlation, and cancellation

**Files:**
- Modify: `lib/core/bridge_models.dart`
- Create: `lib/daemon/delegation_manager.dart`
- Create: `lib/core/bridge_protocol.dart`
- Modify: `lib/daemon/ws_server.dart`
- Modify: `lib/daemon/workflow_engine.dart`
- Modify: `lib/daemon/task_scheduler.dart`
- Modify: `chrome-extension/background.js`
- Modify: `chrome-extension/content.js`
- Create: `test/connector/delegation_protocol_test.js`
- Modify: `test/daemon/ws_server_integration_test.dart`
- Create: `test/daemon/delegation_manager_test.dart`
- Modify: `test/daemon/task_scheduler_test.dart`

**Interfaces:**
- Consumes: Task 3's selected lead dispatch and connector ownership.
- Produces: `BridgeTask.parentTaskId` and `handoffDepth`; browser lead responses may contain the strict `<<BRIGADE_DELEGATE>>{...}` block, which the daemon validates and relays as a correlated child task. Browser task cancellation uses `CANCEL_TASK`. Native connectors may expose the same request as a tool call when supported.

- [x] **Step 1: Add delegation tests** for child creation, result relay, rejected targets, depth limits, and strict marker parsing.
- [x] **Step 2: Run the tests and confirm they fail.** The initial red run failed because delegation APIs and marker parsing were absent.
- [x] **Step 3: Implement delegation entry points.** The daemon wraps browser tasks with marker syntax and parses only a complete valid response block; ordinary prose remains a normal result. Native connector ingress candidates are documented separately, but no native connector is implemented here.
- [x] **Step 4: Implement `DelegationManager.request`.** The manager validates connected target eligibility, instruction size, self-targeting, and depth; child tasks inherit project and parent metadata.
- [x] **Step 5: Relay child results and failures.** Correlated child work returns to the lead in a continuation prompt; the lead produces the final parent result.
- [x] **Step 6: Track concurrent parent/child tasks and propagate cancellation.** Scheduler tracks active task IDs and propagates parent cancellation to children; owner loss fails owned tasks without rerouting.
- [x] **Step 7: Test the review-focus failure cases.** Protocol, manager, scheduler, and authenticated-owner integration tests cover malformed markers, invalid targets, depth, cancellation, and spoofed results.
- [x] **Step 8: Run delegation tests.** Focused delegation, scheduler, integration, protocol, and connector suites passed.

### Task 5: HUD project, lead override, and activity timeline

**Files:**
- Modify: `lib/ui/expanded_editor.dart`
- Modify: `lib/ui/overlay_shell.dart`
- Modify: `lib/ui/node_canvas.dart`
- Modify: `lib/ui/activity_inspector.dart`
- Modify: `lib/ui/approval_modal.dart`
- Modify: `lib/main.dart`
- Modify: `test/ui/expanded_editor_test.dart`
- Modify: `test/ui/overlay_shell_test.dart`

**Interfaces:**
- Consumes: Task 2 `ProjectContext` list/current ID, Task 3 lead candidates, Task 4 parent/child handoff task records, and existing `ExpandedEditor` event callbacks.
- Produces: `typedef DispatchHandler = void Function(String text, {required String projectId, String? targetNodeId})`; HUD callbacks `onSelectProject(String projectId)`, `onCreateProject(String name)`, and `onSelectLead(String? nodeId)`; approval decisions carry `approvalId`, project ID, node ID, and capability to one-time approval or `allowForProject`.

- [x] **Step 1: Add widget tests** for project creation/selection, lead override, and handoff timeline.
- [x] **Step 2: Run the widget tests and confirm they fail.** The initial UI cases failed because project selection and lead overrides were absent.
- [x] **Step 3: Add a project selector and per-command lead selector** with connected-node eligibility and project creation.
- [x] **Step 4: Make the graph visual only.** Routing is selected independently of displayed graph edges.
- [x] **Step 5: Render the handoff chain in activity view.** Activity shows app, parent/child relation, status, result/failure, and stop control.
- [x] **Step 6: Update approval UI.** Choices are **Allow** and **Always allow for this project**, scoped to app, action, and project.
- [x] **Step 7: Run UI tests.** Widget tests passed.

### Task 6: Chrome web research and connector-specific integration

**Files:**
- Modify: `chrome-extension/manifest.json`
- Modify: `chrome-extension/background.js`
- Modify: `chrome-extension/content.js`
- Modify: `lib/daemon/ws_server.dart`
- Modify: `lib/daemon/lead_router.dart`
- Modify: `test/connector/explicit_connection_test.js`
- Create: `test/connector/web_research_test.js`
- Modify: `test/daemon/ws_server_integration_test.dart`

**Interfaces:**
- Consumes: Task 1's active-tab pairing, Task 3's `web_research` capability, and Task 4's authenticated request ownership.
- Produces: `WEB_RESEARCH_REQUEST` and `WEB_RESEARCH_RESULT` messages correlated to the requesting task; the Chrome connector executes a request only through a user-connected browser tab and returns extracted page text and source URLs.

- [x] **Step 1: Add connector tests** proving explicit-tab-only research and correlated results.
- [x] **Step 2: Run the new connector tests and confirm they fail.** The initial run failed because research messages were not handled.
- [x] **Step 3: Add the `web_research` capability** to explicit generic browser connections with bounded correlated payloads.
- [x] **Step 4: Route research through the connected Chrome tab.** The daemon requires a live explicitly connected tab; it does not open or navigate tabs or call an external search API.
- [x] **Step 5: Add tests for unauthorized, stale, and successful results.** Integration coverage verifies owner matching, visible content, and source URLs.
- [x] **Step 6: Run connector and daemon tests.** Connector and WebSocket integration tests passed.

### Task 7: App compatibility and end-to-end verification

**Files:**
- Modify: `README.md`
- Modify: `test/connector/content_protocol_test.js`
- Modify: `test/daemon/ws_server_integration_test.dart`
- Modify: `tool/test_e2e.js`
- Test: the compatibility matrix recorded under Task 1.

**Interfaces:**
- Consumes: Tasks 1–6's explicit connector protocol, project context, routing, delegation, approvals, and browser research.
- Produces: documented setup and a verified end-to-end flow using only manually connected app nodes.

- [x] **Step 1: Add end-to-end cases** for a direct task, a lead delegating to a connected peer, rejection of spoofed unowned results, scoped approvals, and explicit-tab research.
- [x] **Step 2: Run the local automated suite.** `flutter test --concurrency=1` passed (82 tests); JavaScript syntax checks, connector lifecycle/pairing/research tests, and `flutter analyze --no-fatal-infos` completed (warnings/info only).
- [ ] **Step 3: Run the live harness** with a manually connected app and local pairing token. This needs an interactive running macOS app and real authenticated agent tabs, unavailable in this automated workspace; keep as manual release validation.
- [x] **Step 4: Update README setup instructions** to describe explicit per-tab pairing, project selection, approval scope, supported connector matrix, and app-specific limitations.
- [x] **Step 5: Run final targeted integration tests** and confirm there is no automatic all-tab enumeration or global desktop-control path in active dispatch; desktop-node regression and paired-tab tests passed.
