import assert from 'node:assert/strict';
import { afterEach, beforeEach, describe, it } from 'node:test';
import { BridgeClient, BridgeError, validateBridgeUrl } from '../server/bridge_client.js';
import { startFakeDaemon } from './support/fake_daemon.js';

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

describe('validateBridgeUrl', () => {
  it('accepts loopback ws URLs', () => {
    assert.equal(validateBridgeUrl('ws://127.0.0.1:7432'), 'ws://127.0.0.1:7432');
    assert.equal(validateBridgeUrl('ws://localhost:7432'), 'ws://localhost:7432');
    assert.equal(validateBridgeUrl('ws://[::1]:7432'), 'ws://[::1]:7432');
    assert.equal(validateBridgeUrl(), 'ws://127.0.0.1:7432');
  });

  it('rejects remote hosts, other schemes, credentials, paths and junk', () => {
    for (const bad of [
      'ws://example.com:7432', 'wss://127.0.0.1:7432', 'http://127.0.0.1:7432',
      'ws://user:pw@127.0.0.1:7432', 'ws://127.0.0.1:7432/x', 'ws://127.0.0.1:7432?a=1',
      'ws://10.0.0.5:7432', 'not a url', '',
    ]) {
      assert.throws(() => validateBridgeUrl(bad), BridgeError, bad);
    }
  });
});

describe('BridgeClient', () => {
  let daemon;
  let client;

  beforeEach(async () => {
    daemon = await startFakeDaemon();
    client = new BridgeClient({ url: daemon.url, token: daemon.token, startTimeoutMs: 300, requestTimeoutMs: 1000 });
  });
  afterEach(async () => {
    client.close();
    await daemon.close();
  });

  it('refuses to connect without a token', async () => {
    const noToken = new BridgeClient({ url: daemon.url });
    await assert.rejects(noToken.listNodes(), /pairing token/);
  });

  it('reports a rejected token', async () => {
    const bad = new BridgeClient({ url: daemon.url, token: 'wrong', requestTimeoutMs: 1000 });
    await assert.rejects(bad.listNodes(), /rejected the connection.*token was rejected/);
  });

  it('reports an unreachable Bridge', async () => {
    const down = new BridgeClient({ url: 'ws://127.0.0.1:1', token: 'x', requestTimeoutMs: 1000 });
    await assert.rejects(down.listNodes(), /Could not reach Brigade Bridge/);
  });

  it('lists only nodes that can receive tasks', async () => {
    const nodes = await client.listNodes();
    assert.deepEqual(nodes.map((n) => n.id), ['codex:thr_1', 'tab-7']);
  });

  it('runs a job and returns the result', async () => {
    const job = await client.startJob({ nodeId: 'codex:thr_1', instruction: 'Review this' });
    await client.waitForJob(job, 2);
    assert.equal(job.status, 'completed');
    assert.equal(job.result, 'done');

    const run = daemon.received.find((m) => m.type === 'RUN_WORKFLOW').payload;
    assert.equal(run.taskText, 'Review this');
    assert.equal(run.targetNodeId, 'codex:thr_1');
    assert.equal(run.workflowId, job.id);
    assert.equal(run.origin, 'external');
    assert.equal('projectId' in run, false);
  });

  it('passes an explicit project id', async () => {
    const job = await client.startJob({ nodeId: 'tab-7', instruction: 'x', projectId: 'proj-1' });
    await client.waitForJob(job, 2);
    assert.equal(daemon.received.find((m) => m.type === 'RUN_WORKFLOW').payload.projectId, 'proj-1');
  });

  it('rejects an unknown or non-receiving node without starting anything', async () => {
    await assert.rejects(client.startJob({ nodeId: 'nope', instruction: 'x' }), /not a connected app.*codex:thr_1, tab-7/);
    await assert.rejects(client.startJob({ nodeId: 'desktop-1', instruction: 'x' }), /not a connected app/);
    assert.equal(daemon.received.some((m) => m.type === 'RUN_WORKFLOW'), false);
  });

  it('shows the approval wait and then the result', async () => {
    daemon.onRun = (d, p) => {
      d.status(p, 'waitingForApproval');
      setTimeout(() => d.status(p, 'working'), 40);
      setTimeout(() => d.status(p, 'completed', { result: 'approved result' }), 80);
    };
    const job = await client.startJob({ nodeId: 'codex:thr_1', instruction: 'x' });
    await sleep(20);
    assert.equal(job.status, 'waiting_for_approval');
    await client.waitForJob(job, 2);
    assert.equal(job.result, 'approved result');
  });

  it('reports a failed task', async () => {
    daemon.onRun = (d, p) => d.status(p, 'failed', { error: 'usage limit' });
    const job = await client.startJob({ nodeId: 'codex:thr_1', instruction: 'x' });
    await client.waitForJob(job, 2);
    assert.equal(job.status, 'failed');
    assert.equal(job.error, 'usage limit');
  });

  it('ignores other workflows and delegated child tasks', async () => {
    daemon.onRun = (d, p) => {
      d.broadcast('TASK_STATUS_CHANGED', { taskId: 'x', status: 'completed', workflowId: 'someone-else', sourceNodeId: 'user', result: 'WRONG' });
      d.status(p, 'completed', { result: 'child result' }, 'codex:thr_1'); // child of the target
      setTimeout(() => d.status(p, 'completed', { result: 'root result' }), 40);
    };
    const job = await client.startJob({ nodeId: 'codex:thr_1', instruction: 'x' });
    await client.waitForJob(job, 2);
    assert.equal(job.result, 'root result');
  });

  it('fails fast when the daemon refuses to start the task', async () => {
    daemon.onRun = (d) => d.broadcast('PROTOCOL_ERROR', { reason: 'Workflow request failed: Unknown project: nope' });
    const job = await client.startJob({ nodeId: 'codex:thr_1', instruction: 'x', projectId: 'nope' });
    await client.waitForJob(job, 2);
    assert.equal(job.status, 'failed');
    assert.match(job.error, /Unknown project/);
  });

  it('fails fast on the daemon\'s "nothing eligible" log', async () => {
    daemon.onRun = (d) => d.broadcast('LOG_ENTRY', { message: 'The selected app is unavailable or cannot receive tasks', severity: 'warning' });
    const job = await client.startJob({ nodeId: 'codex:thr_1', instruction: 'x' });
    await client.waitForJob(job, 2);
    assert.equal(job.status, 'failed');
    assert.match(job.error, /unavailable/);
  });

  it('times out a task that never starts (for example while Bridge is stopped)', async () => {
    daemon.onRun = () => {};
    const job = await client.startJob({ nodeId: 'codex:thr_1', instruction: 'x' });
    await client.waitForJob(job, 2);
    assert.equal(job.status, 'failed');
    assert.match(job.error, /did not start the task/);
  });

  it('allows only one active job at a time', async () => {
    daemon.onRun = () => {};
    const job = await client.startJob({ nodeId: 'codex:thr_1', instruction: 'x' });
    await assert.rejects(client.startJob({ nodeId: 'tab-7', instruction: 'y' }), new RegExp(`Job ${job.id} is still starting`));
    await client.waitForJob(job, 1); // start timeout frees the slot
    const next = await client.startJob({ nodeId: 'tab-7', instruction: 'y' });
    assert.notEqual(next.id, job.id);
  });

  it('waitForJob returns the current state when the time is up', async () => {
    daemon.onRun = (d, p) => d.status(p, 'working');
    const job = await client.startJob({ nodeId: 'codex:thr_1', instruction: 'x' });
    const t0 = Date.now();
    await client.waitForJob(job, 0.2);
    assert.ok(Date.now() - t0 >= 150);
    assert.equal(job.status, 'running');
  });

  it('cancel asks the daemon to cancel the workflow; finished jobs are left alone', async () => {
    daemon.onRun = (d, p) => d.status(p, 'working');
    const job = await client.startJob({ nodeId: 'codex:thr_1', instruction: 'x' });
    await sleep(20);
    await client.cancelJob(job.id);
    await sleep(20);
    assert.equal(daemon.received.filter((m) => m.type === 'CANCEL_WORKFLOW').length, 1);
    daemon.status({ workflowId: job.id }, 'cancelled', { error: 'cancelled' });
    await client.waitForJob(job, 1);
    await client.cancelJob(job.id);
    assert.equal(daemon.received.filter((m) => m.type === 'CANCEL_WORKFLOW').length, 1);
    assert.throws(() => client.getJob('nope'), /Unknown job/);
  });

  it('marks running jobs unknown when the connection drops', async () => {
    daemon.onRun = (d, p) => d.status(p, 'working');
    const job = await client.startJob({ nodeId: 'codex:thr_1', instruction: 'x' });
    await sleep(20);
    for (const ws of daemon.sockets) ws.terminate();
    await client.waitForJob(job, 2);
    assert.equal(job.status, 'unknown');
    assert.match(job.error, /Lost the connection/);
    // A later call reconnects.
    assert.equal((await client.listNodes()).length, 2);
  });

  it('truncates very large results', async () => {
    daemon.onRun = (d, p) => d.status(p, 'completed', { result: 'x'.repeat(100_000) });
    const job = await client.startJob({ nodeId: 'codex:thr_1', instruction: 'x' });
    await client.waitForJob(job, 2);
    assert.ok(job.result.length < 61_000);
    assert.match(job.result, /truncated 40000 characters/);
  });
});
