# Brigade Bridge Chrome connector

This Manifest V3 extension connects supported AI tabs to the local daemon at
`ws://127.0.0.1:7432`. It uses the browser's existing logged-in session and
does not read cookies, passwords, or provider API keys.

Load it through `chrome://extensions` → **Developer mode** → **Load unpacked**.
Select this directory after starting Brigade Bridge. Open the extension's
Details page → **Extension options**, copy the local pairing token from
Brigade Bridge → expanded view → Settings, and save it once. Reload connected
tabs after pairing.

The connector includes versioned profiles for Claude, Codex/ChatGPT, and Anti
Gravity-style pages, plus a generic browser fallback. Agent selectors,
generation indicators, error states, and stop controls are intentionally
conservative; if a composer or completion state cannot be verified, the task
is reported as failed. The connector never reads cookies, passwords, or
provider API keys.
