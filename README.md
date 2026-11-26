# Brigade Bridge

Brigade Bridge is a local-first macOS overlay for routing work through
explicitly connected, already-open browser tabs. It uses the user's existing
logged-in sessions; it does not use provider API keys or read cookies and
passwords.

## Current workflow

1. Start Brigade Bridge and open the expanded view.
2. Install the shipped `Chrome Connector` folder from `chrome://extensions` with Developer mode.
3. Open the connector's options, paste the local pairing token shown in Bridge Settings, and save it.
4. Open the agent or search page you want to use, then click the connector and choose **Connect this tab**. Repeat for each tab you authorize.
5. Select a project context and enter a command. Automatic routing chooses one eligible connected app; the per-command selector can override that choice.
6. Approve sensitive actions once or choose **Always allow for this project** for that app and capability.

Only tabs you explicitly connect receive tasks. Bridge does not open apps or
tabs, inspect unconnected tabs, or copy project files into a separate runtime.
Project contexts store names and IDs only. The graph is a visual layout and
does not constrain delegation. A connected app may ask Bridge to relay a task
to another connected app; disconnected apps are never selected as fallbacks.

Bridge supports browser-tab connectors and a manually paired OpenCode TUI
session. To connect OpenCode, start its TUI yourself with a loopback listener,
for example `opencode --hostname 127.0.0.1 --port 4096` in the project/session
you want to use. Find the session ID in OpenCode (for example, with the
OpenCode CLI's `session list` command), then open Bridge's Overlay settings and
enter the server URL and session ID under **OpenCode session**. See the
[OpenCode TUI flags](https://opencode.ai/docs/cli/) and
[server API](https://opencode.ai/docs/server/) documentation.
Bridge checks only that server's health and the exact session ID you entered.
It sends messages through OpenCode's session API and uses OpenCode's existing
project and login state. Bridge includes the selected project ID in a visible
context header in each message, but does not pass project paths or copy files.
Only one Bridge task can run in the paired OpenCode session at a time because
OpenCode cancellation aborts the whole session.

The OpenCode connector accepts only unauthenticated HTTP on a loopback host. It
does not support password-protected OpenCode servers or file attachments yet.
It can relay a delegation request to another connected node. The connector
does not expose OpenCode permission prompts to Bridge, so OpenCode's own
confirmation controls remain responsible for its actions. Disconnect and
reconnect are manual, and Bridge does not store the endpoint or session ID.

Codex CLI/app-server has a possible local route, but its Bridge connector is not
implemented. Claude Desktop ingress and Antigravity native IDE ingress remain
unverified; their native apps are not presented as connected nodes. Antigravity
documents a separate CLI route, but Bridge does not use or launch it. Browser
sessions for Claude, ChatGPT/Codex, Antigravity, and other supported web apps
can be connected individually. For web research, open the search/results page
you want and connect that tab; Bridge reads its visible page content and links
without navigating or opening tabs itself.

The source checkout calls this folder `chrome-extension/`; packaged ZIP and
DMG builds include it as `Chrome Connector` beside the application.

The local daemon listens only on loopback port `7432`. Browser sockets must
authenticate with the locally generated pairing token before they can register
tabs or receive tasks. Sensitive actions remain approval-gated, and text task
results are redacted before they are persisted as logs, database status, or
artifacts.

## Development checks

```text
flutter test
flutter analyze --no-fatal-infos
node --check chrome-extension/content.js
node --check chrome-extension/background.js
node --check chrome-extension/popup.js
node test/connector/content_protocol_test.js
node test/connector/explicit_connection_test.js
node test/connector/web_research_test.js
flutter test test/daemon/opencode_connector_test.dart
flutter test test/daemon/opencode_integration_test.dart
swiftc -parse macos/Runner/BridgeChannel.swift macos/Runner/AppDelegate.swift macos/Runner/MainFlutterWindow.swift
```

Automated tests use simulated connectors. For release validation, pair one
OpenCode session and one other connected node, dispatch a task to OpenCode,
confirm it delegates and receives the peer result, cancel another active task,
then disconnect the OpenCode session.

## macOS release prerequisite

The repository contains the macOS runner, native overlay panel, menu-bar item,
global shortcut, Accessibility and Screen Recording permission flow, but a
release `.app`/`.dmg` still requires the full Xcode installation. Command Line
Tools alone cannot resolve Flutter’s macOS Swift packages or produce a signed
application.

The supported macOS deployment target is macOS 12.0 or newer.

After installing Xcode, select its developer directory, complete first launch,
then run:

```text
flutter doctor
flutter run -d macos
flutter build macos --release
```

For a repeatable unsigned or signed distribution build, use
`scripts/package_macos.sh`. Set `SIGNING_IDENTITY` to a Developer ID
Application identity for a notarizable build; without it, the script uses an
ad-hoc signature for local testing.

Live validation still needs real Chrome tabs with the connector installed and
logged into the supported agent applications. Universal application support,
Windows/Linux packaging, signing/notarization, and update delivery remain
follow-on release work.
