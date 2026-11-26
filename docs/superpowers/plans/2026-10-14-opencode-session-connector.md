# OpenCode Existing Session Connector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user explicitly connect Brigade Bridge to one already-running OpenCode server session, send tasks into that session, return results, relay supported delegation requests, and cancel active work.

**Architecture:** Add a Dart connector that talks to the documented [OpenCode local server API](https://opencode.ai/docs/server/) for one user-supplied loopback server URL and session ID. The HUD owns connect/disconnect gestures; the connector never launches OpenCode, starts a server, lists sessions, scans ports, or chooses a session. Register the resulting node in the existing registry only after the user presses Connect, then use the existing routing and delegation coordinator.

**Tech Stack:** Flutter/Dart 3, `dart:io` HTTP client, existing Drift node registry, task scheduler/event bus, Flutter widget and daemon tests.

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
- This task supports one explicitly entered OpenCode session on a loopback endpoint; it does not implement Claude, Antigravity, or Codex connectors.
- The user starts OpenCode and its server. Bridge must not execute `opencode`, start a server, enumerate sessions, probe ports, or reconnect automatically after restart.
- The connector stores no server password or API key. This first version accepts only unauthenticated HTTP on loopback; reject non-loopback hosts and HTTPS endpoints until a reviewed credential design exists.

## Review Focus

- **Wrong or stale session ID:** Pairing must validate that the entered session can be addressed without listing or switching sessions; failures must leave the node disconnected. Pin in connector validation tests (Task 1).
- **Remote URL or host escape:** Reject non-loopback hosts, non-HTTP schemes, credentials embedded in URLs, and malformed ports before sending requests. Pin in URL validation tests (Task 1).
- **Server unavailable after explicit connect:** Mark the node unavailable and fail its active tasks; do not retry another app or silently reconnect. Pin in daemon integration tests (Task 2).
- **Session-wide cancellation:** OpenCode abort affects the whole session, so reject overlapping tasks and verify cancellation only aborts the one active request (Task 1).
- **Cancellation and delegation:** Send abort only for the paired session and parse delegation only through the existing strict protocol; do not infer sensitive-action approval support. Pin in tests (Tasks 2–3).

---

## File map

- `lib/daemon/opencode_connector.dart` (new) — validates an explicitly entered loopback URL/session, sends messages, returns result text, aborts the active task, and exposes only documented connector capabilities.
- `lib/daemon/daemon.dart` — handle explicit OpenCode connect/disconnect commands and wire the connector to task dispatch without startup discovery.
- `lib/daemon/ws_server.dart` — keep browser socket protocol unchanged; expose or reuse shared task dispatch/cancel hooks as needed rather than treating the OpenCode session as a browser tab.
- `lib/ui/expanded_editor.dart` — add a manual OpenCode connection form with server URL and session ID, plus visible connected/disconnect state.
- `lib/main.dart` — translate HUD connect/disconnect actions to daemon commands and reflect connector state in the node list.
- `test/daemon/opencode_connector_test.dart` (new) — endpoint validation, protocol payloads, result parsing, error mapping, and cancellation against a local fake HTTP server.
- `test/daemon/opencode_integration_test.dart` (new) — explicit connect lifecycle, dispatch, failure, cancellation, and disconnect behavior.
- `test/ui/expanded_editor_test.dart` — pairing form, validation message, and explicit disconnect action.
- `README.md` — document prerequisites, pairing steps, supported operations, and the unsupported approval event limitation.

## Interfaces

- `OpenCodeConnector.validateEndpoint({required String serverUrl, required String sessionId}) -> Uri` accepts only `http://localhost`, `http://127.0.0.1`, or a literal loopback IPv6 host, a valid port, no URL credentials/query/fragment, and a session ID of 1–256 characters with no slash, backslash, whitespace, or control characters; encode the ID as one URI path segment.
- `OpenCodeConnector.connect() -> Future<BridgeNode>` checks server health and requests only `/session/<entered-id>`; it never enumerates sessions. It returns a node with stable ID `opencode:<sessionId>` and capabilities `receive_task`, `cancel_task`. The existing Bridge delegation directive relays to any manually connected peer; this connector does not claim `sensitive_action_approval`.
- `OpenCodeConnector.sendTask(BridgeTask task, {String? prompt}) -> Future<String>` posts the task prompt to the paired session using OpenCode's documented synchronous session message API and returns its assistant response. The API has no structured arbitrary metadata field, so include the required project ID in a small visible context header; never include a local path. Correlate results by the local in-flight request map.
- OpenCode's abort endpoint is session-wide. Permit only one active Bridge task per paired session; reject overlapping dispatches without marking the connection unavailable.
- `OpenCodeConnector.cancelTask(String bridgeTaskId) -> Future<void>` aborts the paired OpenCode session only when that Bridge task is active.
- Connect/disconnect daemon commands carry the server URL and session ID only at user action time. Do not persist these values or establish a connection on app startup in this first version.

---

### Task 1: Implement and test the explicit OpenCode HTTP client

**Files:**
- Create: `lib/daemon/opencode_connector.dart`
- Create: `test/daemon/opencode_connector_test.dart`

**Interfaces:**
- Produces the `OpenCodeConnector` interface listed above.
- Use an injectable `HttpClient` factory or base transport so tests can run against a loopback fake server without contacting an installed OpenCode process.

- [x] **Step 1: Add URL and session validation tests.** Cover loopback forms and reject remote hosts, HTTPS, embedded credentials, query/fragment, invalid or missing ports, empty/overlong session IDs, and IDs containing path separators, whitespace, or control characters.
- [x] **Step 2: Run the connector test and confirm the new API fails before implementation.** The red run failed on the missing connector class; a later URL case caught and fixed implicit port 80 acceptance.
- [x] **Step 3: Implement strict endpoint validation and direct session addressing.** The connector checks only `/global/health` and the exact `/session/<id>` path; it does not call any session-list or process-discovery endpoint.
- [x] **Step 4: Test the outbound message body and response parsing.** Tests verify prompt and project-ID context, assistant text, and malformed/non-success failure behavior.
- [x] **Step 5: Implement task cancellation and session concurrency guard.** Reject overlapping work because abort affects the whole session; abort only the active task in its explicitly paired session.
- [x] **Step 6: Run the connector tests and confirm all pass.**

### Task 2: Wire explicit connection, single-session dispatch, and lifecycle

**Files:**
- Modify: `lib/daemon/daemon.dart`
- Modify: `lib/daemon/node_registry.dart`
- Modify: `lib/daemon/task_scheduler.dart`
- Modify: `lib/daemon/event_bus.dart`
- Modify: `lib/daemon/ws_server.dart` only where shared task/cancel hooks are required
- Create: `test/daemon/opencode_integration_test.dart`

**Interfaces:**
- Consumes: `OpenCodeConnector` from Task 1 and existing `BridgeNode`, `BridgeTask`, `WorkflowEngine`, and `NodeRegistry` APIs.
- Produces: explicit `CONNECT_OPENCODE` and `DISCONNECT_OPENCODE` daemon commands; a connected node event only after successful pairing; task results/failures returned through the same scheduler and event path used by browser connectors.

- [x] **Step 1: Add integration cases** proving only explicit connect registers the selected session, disconnect removes it, and another session on the server is never listed or addressed.
- [x] **Step 2: Add dispatch cases** proving a task reaches only the paired session, the result remains associated with its request, and HTTP failure marks the node unavailable without rerouting.
- [x] **Step 3: Add cancellation cases** proving workflow cancellation and disconnect abort only the paired session; disconnect removes the node and fails active work.
- [x] **Step 4: Implement daemon lifecycle and task dispatch.** Reuse existing workflow scheduling and delegation validation through `WsServer` and `DelegationManager`.
- [x] **Step 5: Run connector, integration, node-registry, and WebSocket tests.** Focused OpenCode suites passed; adjacent regression suites are included in final verification.

### Task 3: Add manual HUD pairing and user-visible state

**Files:**
- Modify: `lib/ui/expanded_editor.dart`
- Modify: `lib/main.dart`
- Modify: `test/ui/expanded_editor_test.dart`

**Interfaces:**
- Consumes: Task 2 connect/disconnect daemon commands and connected-node events.
- Produces: an OpenCode form for server URL and session ID, an explicit Connect action, a Disconnect action for the connected session, and a clear status/error message.

- [x] **Step 1: Add widget tests** for the manual form, invalid endpoint feedback, explicit connect callback arguments, connected state, and disconnect callback.
- [x] **Step 2: Run the focused widget tests and confirm the new cases fail.** The red run failed on the missing form callbacks.
- [x] **Step 3: Add the pairing form to Connections settings.** No discovery, session picker, launch button, project path, or credential/API-key field is offered.
- [x] **Step 4: Wire form actions and connector events through `main.dart`.** No startup or restore auto-connect was added.
- [x] **Step 5: Run `flutter test test/ui/expanded_editor_test.dart` and confirm all pass.**

### Task 4: Document support boundary and run integration verification

**Files:**
- Modify: `README.md`
- Test: `test/daemon/opencode_connector_test.dart`
- Test: `test/daemon/opencode_integration_test.dart`
- Test: `test/ui/expanded_editor_test.dart`

**Interfaces:**
- Consumes: Tasks 1–3's explicit connection lifecycle and documented supported operations.
- Produces: setup instructions requiring a user-started OpenCode server/session, a compatibility statement that sensitive-action approvals are unsupported by this connector, and local automated evidence for request, result, delegation, cancellation, failure, and disconnect paths.

- [x] **Step 1: Update the README compatibility section** with the OpenCode TUI workflow and limitations; keep Claude Desktop, native Antigravity, and Codex app unsupported/unverified until their connectors are verified.
- [x] **Step 2: Run focused tests:** connector, integration, and pairing widget suites passed.
- [x] **Step 3: Run static checks:** `git diff --check` passed. Full-workspace `flutter analyze --no-fatal-infos` exits 1 on three pre-existing warnings in `activity_inspector.dart` and `ws_server_integration_test.dart`; scoped analysis of the nine connector-related files exits 0 with warnings/infos nonfatal (14 style infos remain).
- [x] **Step 4: Record manual release validation** requiring a user to start OpenCode, connect one chosen session, pair a second node, send a task with delegation, cancel active work, and disconnect. The live workflow itself remains unverified.
- [x] **Review follow-up:** include the project ID in a visible context header because OpenCode exposes no structured arbitrary metadata field; reject overlapping session work because abort is session-wide. Connector and full-suite verification pass.

## Compatibility scope after this plan

This plan adds only the OpenCode connector. Codex app-server integration, Antigravity native/CLI integration, and Claude Desktop ingress each need separate compatibility plans after their supported existing-session interfaces and explicit pairing model are verified. Until then, do not show those apps as native connected nodes.
