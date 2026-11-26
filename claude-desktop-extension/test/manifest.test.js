import assert from 'node:assert/strict';
import fs from 'node:fs';
import { describe, it } from 'node:test';
import { createServer } from '../server/tools.js';

const root = new URL('../', import.meta.url);
const manifest = JSON.parse(fs.readFileSync(new URL('manifest.json', root), 'utf8'));

describe('extension packaging', () => {
  it('anchors every .mcpbignore pattern to the extension root', () => {
    // An unanchored "dist/" also matches node_modules/**/dist and the packed
    // extension then crashes on start-up with missing SDK files.
    const patterns = fs.readFileSync(new URL('.mcpbignore', root), 'utf8').split('\n').map((l) => l.trim()).filter((l) => l && !l.startsWith('#'));
    assert.ok(patterns.length > 0);
    for (const pattern of patterns) {
      assert.ok(pattern.startsWith('/'), `"${pattern}" must start with "/"`);
    }
  });

  it('keeps the manifest tool list in sync with the server', async () => {
    const registered = Object.keys(createServer({})._registeredTools).sort();
    assert.deepEqual(manifest.tools.map((t) => t.name).sort(), registered);
  });

  it('passes every user_config value to the server through env', () => {
    const env = manifest.server.mcp_config.env;
    for (const key of Object.keys(manifest.user_config)) {
      assert.ok(Object.values(env).some((v) => v === `\${user_config.${key}}`), `${key} is not mapped to an env var`);
    }
    assert.equal(manifest.user_config.bridge_token.sensitive, true);
    assert.equal(manifest.user_config.bridge_token.required, true);
  });

  it('launches the declared entry point', () => {
    assert.equal(manifest.server.type, 'node');
    assert.ok(fs.existsSync(new URL(manifest.server.entry_point, root)));
    assert.ok(manifest.server.mcp_config.args.includes(`\${__dirname}/${manifest.server.entry_point}`));
  });
});
