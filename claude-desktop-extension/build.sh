#!/usr/bin/env bash
# Builds dist/brigade-bridge.mcpb from a clean copy so only production
# dependencies are bundled. Run `npm install` once first (for the mcpb tool).
set -euo pipefail
cd "$(dirname "$0")"

npx --no-install mcpb validate manifest.json

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
cp -r manifest.json package.json package-lock.json .mcpbignore server "$stage/"
(cd "$stage" && npm ci --omit=dev --silent)

mkdir -p dist
npx --no-install mcpb pack "$stage" dist/brigade-bridge.mcpb
echo "Built $(pwd)/dist/brigade-bridge.mcpb"
