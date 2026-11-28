import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { afterEach, beforeEach, describe, it } from 'node:test';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { startFakeDaemon } from './support/fake_daemon.js';

const entry = fileURLToPath(new URL('../server/index.js', import.meta.url));

async function connect(env) {
  const transport = new StdioClientTransport({
    command: process.execPath,
    args: [entry],
    env: { PATH: process.env.PATH, ...env },
    stderr: 'pipe',
  });
  const client = new Client({ name: 'test-client', version: '1.0.0' });
  await client.connect(transport);
  return client;
}

const textOf = (result) => result.content.map((c) => c.text).join('\n');

describe('Brigade Bridge MCP server (over stdio)', () => {
  let daemon;
  let client;

  beforeEach(async () => {
    daemon = await startFakeDaemon();
    client = await connect({ BRIDGE_URL: daemon.url, BRIDGE_TOKEN: daemon.token });
  });
  afterEach(async () => {
    await client.close();
    await daemon.close();
  });

  it('exposes the four tools with safety annotations', async () => {
    const { tools } = await client.listTools();
    assert.deepEqual(tools.map((t) => t.name).sort(),
      ['bridge_cancel', 'bridge_delegate', 'bridge_get_result', 'bridge_list_nodes']);
    const byName = Object.fromEntries(tools.map((t) => [t.name, t]));
    assert.equal(byName.bridge_list_nodes.annotations.readOnlyHint, true);
    assert.equal(byName.bridge_get_result.annotations.readOnlyHint, true);
    assert.equal(byName.bridge_delegate.annotations.readOnlyHint, false);
    assert.equal(byName.bridge_delegate.annotations.destructiveHint, true);
    assert.deepEqual(byName.bridge_delegate.inputSchema.required.sort(), ['instruction', 'node_id']);
  });

  it('lists connected apps', async () => {
    const result = await client.callTool({ name: 'bridge_list_nodes', arguments: {} });
    const nodes = JSON.parse(textOf(result));
    assert.deepEqual(nodes.map((n) => n.id), ['codex:thr_1', 'tab-7']);
    assert.equal(nodes[0].name, 'Codex');
  });

  it('delegates a task and returns the answer', async () => {
    daemon.onRun = (d, p) => d.status(p, 'completed', { result: 'Codex says hi' });
    const result = await client.callTool({
      name: 'bridge_delegate',
      arguments: { node_id: 'codex:thr_1', instruction: 'Say hi', wait_seconds: 5 },
    });
    assert.notEqual(result.isError, true);
    const body = JSON.parse(textOf(result));
    assert.equal(body.status, 'completed');
    assert.equal(body.result, 'Codex says hi');
    assert.match(body.job_id, /^mcp-/);
  });

  it('returns a job id for slow tasks and lets Claude keep waiting', async () => {
    daemon.onRun = (d, p) => {
      d.status(p, 'waitingForApproval');
      setTimeout(() => d.status(p, 'completed', { result: 'late answer' }), 1800);
    };
    const first = JSON.parse(textOf(await client.callTool({
      name: 'bridge_delegate',
      arguments: { node_id: 'tab-7', instruction: 'Slow one', wait_seconds: 1 },
    })));
    assert.equal(first.status, 'waiting_for_approval');
    assert.match(first.note, /approve .* Brigade Bridge/);

    const done = JSON.parse(textOf(await client.callTool({
      name: 'bridge_get_result',
      arguments: { job_id: first.job_id, wait_seconds: 5 },
    })));
    assert.equal(done.status, 'completed');
    assert.equal(done.result, 'late answer');
  });

  it('reports a failed delegation as a tool error', async () => {
    daemon.onRun = (d, p) => d.status(p, 'failed', { error: 'usage limit' });
    const result = await client.callTool({
      name: 'bridge_delegate',
      arguments: { node_id: 'codex:thr_1', instruction: 'x', wait_seconds: 5 },
    });
    assert.equal(result.isError, true);
    assert.match(textOf(result), /usage limit/);
  });

  it('reports an unknown app as a tool error without sending work', async () => {
    const result = await client.callTool({
      name: 'bridge_delegate',
      arguments: { node_id: 'ghost', instruction: 'x' },
    });
    assert.equal(result.isError, true);
    assert.match(textOf(result), /not a connected app/);
    assert.equal(daemon.received.some((m) => m.type === 'RUN_WORKFLOW'), false);
  });

  it('validates arguments before touching Bridge', async () => {
    for (const args of [
      { node_id: 'codex:thr_1', instruction: '' },
      { node_id: '', instruction: 'x' },
      { node_id: 'codex:thr_1', instruction: 'x', wait_seconds: 999 },
    ]) {
      const outcome = await client.callTool({ name: 'bridge_delegate', arguments: args }).catch((e) => ({ isError: true, thrown: e }));
      assert.equal(outcome.isError, true, JSON.stringify(args));
    }
    assert.equal(daemon.received.some((m) => m.type === 'RUN_WORKFLOW'), false);
  });

  it('cancels a running job', async () => {
    daemon.onRun = (d, p) => d.status(p, 'working');
    const started = JSON.parse(textOf(await client.callTool({
      name: 'bridge_delegate',
      arguments: { node_id: 'codex:thr_1', instruction: 'x', wait_seconds: 0 },
    })));
    const result = await client.callTool({ name: 'bridge_cancel', arguments: { job_id: started.job_id } });
    assert.notEqual(result.isError, true);
    await new Promise((r) => setTimeout(r, 50));
    assert.equal(daemon.received.filter((m) => m.type === 'CANCEL_WORKFLOW').length, 1);
  });
});

describe('Brigade Bridge MCP server configuration', () => {
  it('starts without a token and explains how to fix it when a tool is used', async () => {
    const client = await connect({});
    try {
      const result = await client.callTool({ name: 'bridge_list_nodes', arguments: {} });
      assert.equal(result.isError, true);
      assert.match(textOf(result), /pairing token/);
    } finally {
      await client.close();
    }
  });

  it('refuses to start with a non-loopback Bridge URL', async () => {
    await assert.rejects(connect({ BRIDGE_URL: 'ws://example.com:7432', BRIDGE_TOKEN: 'x' }));
  });
});
