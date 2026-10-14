# Brigade Bridge: Explicit App Collaboration Design

## Purpose

Brigade Bridge is a lightweight macOS HUD that lets a user route work among
AI-enabled applications they have opened and explicitly connected. The
connected applications use their existing logged-in sessions and subscriptions.
Bridge coordinates messages and delegated work without creating a separate
agent environment or requiring provider API keys.

The user remains responsible for opening applications and connecting them.
Bridge must never launch applications, discover unconnected applications, or
control applications outside an explicit connector.

## Product goals

- Provide a clean overlay for entering commands, choosing or accepting a lead
  application, viewing connected application nodes, and following work.
- Let Bridge choose a suitable connected application for a command, while
  allowing the user to override the choice for that command.
- Let a lead application complete a task itself or request specific help from
  another connected application when that would help.
- Relay delegated tasks and their results between connected applications.
- Keep connected apps working in their existing sessions and the same active
  project context.
- Require explicit approval for sensitive actions, with one-time and
  project-scoped choices.
- Let an explicitly connected Chrome node provide web research through the
  user's existing browser session.

## Non-goals and boundaries

- No provider API keys or separate paid model environment.
- No Bridge-created workspace, agent runtime, or project copy.
- No launching, scanning, or controlling applications that the user has not
  explicitly connected.
- No direct app-to-app network channel. Bridge is the relay between connectors.
- The node graph is a visual map. Its lines do not grant, deny, or constrain
  delegation paths.
- Connecting an app permits task and response exchange through its connector;
  it does not automatically approve sensitive actions.

## User experience

The macOS HUD contains:

1. A command entry area.
2. An active project selector. This is the context used for routing and
   project-scoped approvals; it does not give Bridge access to project files.
3. A node graph showing the applications the user has connected. Any layout or
   lines are for orientation only.
4. A per-command lead-app choice, defaulted by Bridge and editable by the user.
5. A task activity view showing the lead, delegated subtasks, results, and
   current status, with a way to stop active work.
6. Approval prompts that identify the requesting app, action, and active
   project. Choices are **Allow** for the requested action or **Always allow
   for this project** for matching future actions in that project.

Switching the active project changes the context for subsequent work and
project-scoped approvals. A grant for one project does not apply to another.

## Architecture

### HUD and coordinator

The Flutter macOS overlay presents the command, project, connected nodes,
activity, and approvals. The local daemon coordinates tasks, connector
connections, handoff state, and project-scoped approval records. It does not
open target apps or inspect project files to create a workspace.

### Explicit app connectors

An app becomes available only after the user initiates its connector and pairs
it with Bridge. A connector exposes the narrow operations it supports, such as
receiving a task, returning a result, requesting delegation, or requesting a
sensitive action approval. The user may disconnect it at any time. Disconnected
or unavailable apps are ineligible for routing and delegation.

Connectors use the app's existing signed-in session. For browser-based apps,
the Chrome extension is the connector; only tabs the user connects are
available. For native apps, a supported explicit integration is required. An
app without a supported connector cannot be controlled by Bridge.

### Task routing

When a command is submitted, Bridge chooses a lead from the currently connected
and available apps using connector-declared capabilities and task fit. The user
may select a different lead for that command. Bridge does not broadcast every
command to every app or ask every app to evaluate it.

The lead app receives the user's command through its existing session. It may
complete the task itself. If it needs help, it sends an explicit delegation
request through its connector. Bridge validates that the requested target is
connected and available, sends the subtask to that app, and returns the result
to the requesting app. The lead can then continue, delegate another subtask,
or return a final result. Bridge records the handoff chain and presents its
progress in the HUD.

No fixed multi-app sequence is required. The lead decides whether delegation is
useful based on the task; Bridge supplies the relay and enforces connection and
approval boundaries.

### Project context

The user selects the active project in the HUD. That selection identifies the
context and permission scope for a task. The user opens the project in the
connected apps they want to participate. Bridge passes the project identifier
with task and handoff messages but does not create or mount a separate project
environment.

The project selector is metadata and approval scope; it does not grant Bridge
filesystem access. Connectors and target apps continue to use their own
existing project/session state.

### Sensitive action approvals

Ordinary message exchange between connected apps proceeds without an approval
prompt. A connector must request approval before a sensitive action that it
supports, such as editing project files or running a command. The prompt states
the requesting app, the proposed action, and the active project.

- **Allow** authorizes only the presented action.
- **Always allow for this project** stores consent for matching actions in the
  selected project. It has no effect in other projects.
- Switching projects changes the scope for future requests; the user must grant
  permission separately in each project.
- An app's own confirmation and safety controls remain in effect. Bridge
  approval does not bypass them.

If a connector cannot surface a sensitive action request, Bridge cannot claim
to mediate that action; that connector must rely on the target app's own
controls and must clearly report this limitation.

### Chrome web research

Chrome is represented as a connected app node only when the user explicitly
connects it. A lead app may request web research through that node. Bridge
relays the request through the Chrome connector and returns the result. Bridge
does not use an independent browser or web-search service for this workflow.

## Connector contract

Every connector declares an application identity, supported capabilities,
connection state, and a protocol version. The minimum collaboration contract
supports:

- Pairing and explicit disconnect.
- Receiving a task with its project identifier and task correlation identifier.
- Returning progress, completion, or a clear failure.
- Issuing a delegation request and receiving the delegated result.
- Requesting sensitive-action approval when the connector can mediate that
  action.

The daemon validates every message against the connection that sent it,
correlation identifiers, declared capabilities, and current approval state.
Results and failures are returned to the initiating app and shown in the HUD.

## Failure handling and user control

- If a connector drops during a task, Bridge marks that app unavailable,
  reports the interrupted task, and does not silently move the work to an
  unconnected app.
- If a delegation target is disconnected or does not support the requested
  capability, Bridge returns a failure to the requesting app so it can
  continue or report the limitation.
- The HUD shows which app is working at each step and offers a stop control
  for active work. Stop cancels pending handoffs and sends cancellation through
  active connectors where supported.
- Bridge keeps a task and handoff history sufficient to explain which
  connected apps received work and what they returned.

## Acceptance criteria

1. An app cannot receive work until the user explicitly connects its
   connector.
2. Bridge never launches or discovers applications on the user's behalf.
3. A command can be routed to one lead app, with a per-command user override.
4. The lead can finish without delegation; no other app receives the command
   unless it is explicitly requested as a handoff.
5. A lead can delegate through Bridge to another connected app and receive its
   result, with the handoff visible in the HUD.
6. The node graph does not act as a permission or routing graph.
7. Selecting a project scopes task context and stored approvals without giving
   Bridge direct access to project files.
8. A one-time approval applies only to the presented sensitive action; a
   project-wide approval applies only to matching future actions in that
   project.
9. A connected Chrome node can provide web research through its explicit
   connector, and no unconnected browser context is used.
10. A disconnected connector is unavailable for new routing and handoffs.

## Delivery sequence

1. Define and implement the explicit connector lifecycle and message contract.
2. Make the HUD show connected app nodes, active project, and per-command lead
   selection/override.
3. Route one command to one connected lead app and relay its result.
4. Add explicit delegation requests, subtask correlation, result return, and
   visible handoff history.
5. Add project-scoped sensitive-action approval requests and grants for
   connectors that can mediate those actions.
6. Add Chrome web research through the explicitly connected browser connector.
7. Validate connection loss, cancellation, project switching, and unavailable
   delegation targets.
