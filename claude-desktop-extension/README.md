# Brigade Bridge extension for Claude Desktop

Lets Claude Desktop hand a task to another app you have connected to Brigade
Bridge (Codex, Antigravity, Claude Code, a browser tab, ...) and read the answer
back. The other app uses its own login; no API keys are involved.

This is the **outbound** direction only: Claude can send work to your other
apps. Bridge cannot push tasks *into* the Claude Desktop chat app (it has no
documented way to receive them). To send work *to* Claude from Bridge, connect
Claude Code instead (Overlay settings → Claude Code).

## Install

1. Build the bundle (needs Node 18+):

   ```bash
   cd claude-desktop-extension
   npm install
   npm run pack          # writes dist/brigade-bridge.mcpb
   ```

2. In Claude Desktop open **Settings → Extensions → Advanced settings → Install
   Extension…** and choose `dist/brigade-bridge.mcpb`.
3. When asked, paste the **Bridge pairing token**: in Brigade Bridge open
   *Overlay settings → Claude Desktop extension → Set up*, reveal or copy the
   token and the address. Claude Desktop
   stores it as a sensitive setting. Leave the address as `ws://127.0.0.1:7432`.
4. Keep Brigade Bridge running and connect the apps you want Claude to use.

## Tools

| Tool | What it does |
| --- | --- |
| `bridge_list_nodes` | Lists connected apps that can receive a task (read-only). |
| `bridge_delegate` | Sends a self-contained instruction to one app and returns its answer. Waits up to `wait_seconds` (default 45, max 55). |
| `bridge_get_result` | Keeps waiting for, or checks, a task by `job_id` (read-only). |
| `bridge_cancel` | Asks Bridge to cancel the delegated workflow. |

Long tasks do not time out: `bridge_delegate` returns a `job_id` and a status,
and Claude calls `bridge_get_result` until it finishes. Only one delegation runs
at a time.

## Safety model

- **Bridge stays in charge.** Delegated tasks go through Bridge's normal
  approval flow. If the status is `waiting_for_approval`, the user has to approve
  in the Brigade Bridge window; the extension cannot approve anything.
- **Emergency Stop is respected.** A delegation from this extension never clears
  Bridge's Stop. While Bridge is stopped the task fails with "Bridge is stopped"
  until the user resumes it in Bridge.
- **Local only.** The extension refuses any address that is not loopback, and
  Bridge itself only listens on `127.0.0.1`. The token is a local pairing token,
  not a cloud credential.
- **Claude asks you first.** `bridge_delegate` is marked as non-read-only, so
  Claude Desktop asks for your permission before it runs. Tool descriptions tell
  Claude to delegate only when you asked and never to include secrets.
- **Delegation chains are bounded** by Bridge (at most 8 hand-offs).

## Troubleshooting

- *"Could not reach Brigade Bridge"* — start the app; check the address.
- *"rejected the connection ... token"* — re-copy the pairing token (it may have
  been regenerated) in the extension's settings.
- *"is not a connected app that can receive tasks"* — call `bridge_list_nodes`
  and connect the app in Bridge first.
- *"did not start the task"* — the app disconnected, or Bridge is stopped.

## Development

```bash
npm test      # unit + end-to-end tests against a fake Bridge daemon
```

The end-to-end tests run the real server over stdio with the official MCP
client. The extension has **not yet been tested inside Claude Desktop itself**.
