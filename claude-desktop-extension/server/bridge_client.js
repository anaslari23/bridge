import { randomUUID } from 'node:crypto';
import WebSocket from 'ws';

export const DEFAULT_URL = 'ws://127.0.0.1:7432';
const TERMINAL = new Set(['completed', 'failed', 'stopped', 'cancelled']);
const MAX_RESULT_CHARS = 60_000;

// Daemon log lines that mean RUN_WORKFLOW was accepted but nothing will run.
const START_FAILURE_LOGS = [
  /No connected app is eligible/i,
  /selected app is unavailable/i,
  /Selected lead is no longer connected/i,
  /Workflow already exists/i,
  /Duplicate workflow ignored/i,
];

export class BridgeError extends Error {}

/** The daemon only ever listens on loopback; refuse anything else. */
export function validateBridgeUrl(raw = DEFAULT_URL) {
  let url;
  try {
    url = new URL(raw);
  } catch {
    throw new BridgeError('The Bridge URL is not a valid URL');
  }
  const host = url.hostname.replace(/^\[|\]$/g, '').toLowerCase();
  const loopback = host === 'localhost' || host === '::1' || /^127\.\d+\.\d+\.\d+$/.test(host);
  if (url.protocol !== 'ws:' || !loopback || url.username || url.password || url.search || url.hash || (url.pathname !== '/' && url.pathname !== '')) {
    throw new BridgeError('The Bridge URL must be a ws:// address on this computer, for example ws://127.0.0.1:7432');
  }
  return url.toString().replace(/\/$/, '');
}

function truncate(text) {
  if (typeof text !== 'string') return text;
  return text.length <= MAX_RESULT_CHARS
    ? text
    : `${text.slice(0, MAX_RESULT_CHARS)}\n…[truncated ${text.length - MAX_RESULT_CHARS} characters]`;
}

/**
 * Talks to the Brigade Bridge daemon on loopback. One job runs at a time:
 * Bridge's approval prompts and workflow engine are shared with the user's own
 * work, so this client never queues up parallel delegations.
 */
export class BridgeClient {
  #ws = null;
  #connecting = null;
  #pendingList = [];
  #url;
  #token;
  #requestTimeoutMs;
  #startTimeoutMs;
  #WebSocketImpl;
  jobs = new Map();

  constructor({ url = DEFAULT_URL, token, requestTimeoutMs = 8000, startTimeoutMs = 15000, WebSocketImpl = WebSocket } = {}) {
    this.#url = validateBridgeUrl(url);
    this.#token = token;
    this.#requestTimeoutMs = requestTimeoutMs;
    this.#startTimeoutMs = startTimeoutMs;
    this.#WebSocketImpl = WebSocketImpl;
  }

  async #connect() {
    if (!this.#token) {
      throw new BridgeError('Set the Bridge pairing token in this extension\'s settings (shown in Brigade Bridge under Overlay settings)');
    }
    if (this.#ws && this.#ws.readyState === 1) return;
    if (this.#connecting) return this.#connecting;
    this.#connecting = new Promise((resolve, reject) => {
      let settled = false;
      const done = (error) => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        this.#connecting = null;
        if (error) {
          try { ws.terminate(); } catch { /* already closed */ }
          reject(error);
        } else {
          resolve();
        }
      };
      const ws = new this.#WebSocketImpl(this.#url);
      const timer = setTimeout(
        () => done(new BridgeError('Brigade Bridge did not answer. Is the app running?')),
        this.#requestTimeoutMs,
      );
      ws.on('open', () => ws.send(JSON.stringify({ type: 'AUTHENTICATE', payload: { token: this.#token } })));
      ws.on('message', (raw) => {
        let msg;
        try { msg = JSON.parse(raw.toString()); } catch { return; }
        if (msg.type === 'AUTHENTICATED') {
          this.#ws = ws;
          done();
        } else if (!settled && msg.type === 'PROTOCOL_ERROR') {
          done(new BridgeError(`Brigade Bridge rejected the connection: ${msg.payload?.reason ?? 'unknown reason'}`));
        } else if (settled) {
          this.#onMessage(msg);
        }
      });
      ws.on('error', () => done(new BridgeError('Could not reach Brigade Bridge. Is the app running?')));
      ws.on('close', () => {
        if (!settled) done(new BridgeError('Brigade Bridge closed the connection. Check the pairing token.'));
        else this.#onClosed(ws);
      });
    });
    return this.#connecting;
  }

  #onClosed(ws) {
    if (this.#ws !== ws) return;
    this.#ws = null;
    for (const waiter of this.#pendingList.splice(0)) {
      waiter.reject(new BridgeError('Lost the connection to Brigade Bridge'));
    }
    for (const job of this.jobs.values()) {
      if (!TERMINAL.has(job.status) && job.status !== 'unknown') {
        this.#update(job, 'unknown', { error: 'Lost the connection to Brigade Bridge; the task may still be running there' });
      }
    }
  }

  #update(job, status, extra = {}) {
    job.status = status;
    job.updatedAt = Date.now();
    Object.assign(job, extra);
    if (TERMINAL.has(status) || status === 'unknown') {
      clearTimeout(job.startTimer);
      for (const resolve of job.waiters.splice(0)) resolve(job);
    }
  }

  #onMessage(msg) {
    const payload = msg.payload ?? {};
    switch (msg.type) {
      case 'NODE_LIST':
        this.#pendingList.shift()?.resolve(payload.nodes ?? []);
        break;
      case 'TASK_STATUS_CHANGED': {
        const job = this.jobs.get(payload.workflowId);
        if (!job) break;
        if (payload.sourceNodeId !== 'user') {
          // A task the target delegated onward; only the root task is the job.
          job.delegations = (job.delegations ?? 0) + (payload.status === 'created' || payload.status === 'queued' ? 1 : 0);
          break;
        }
        if (TERMINAL.has(job.status)) break;
        const map = { created: 'running', queued: 'running', working: 'running', waitingForApproval: 'waiting_for_approval', paused: 'paused' };
        if (payload.status === 'completed') {
          this.#update(job, 'completed', { result: truncate(payload.result ?? '') });
        } else if (TERMINAL.has(payload.status)) {
          this.#update(job, payload.status, { error: payload.error ?? `Task ${payload.status}` });
        } else if (map[payload.status]) {
          this.#update(job, map[payload.status]);
        }
        break;
      }
      case 'LOG_ENTRY': {
        const starting = [...this.jobs.values()].find((job) => job.status === 'starting');
        if (starting && START_FAILURE_LOGS.some((re) => re.test(payload.message ?? ''))) {
          this.#update(starting, 'failed', { error: payload.message });
        }
        break;
      }
      case 'PROTOCOL_ERROR': {
        const reason = payload.reason ?? 'Brigade Bridge reported an error';
        const starting = [...this.jobs.values()].find((job) => job.status === 'starting');
        if (starting) this.#update(starting, 'failed', { error: reason });
        else this.#pendingList.shift()?.reject(new BridgeError(reason));
        break;
      }
      default:
        break;
    }
  }

  /** Connected, receive-capable nodes the user can delegate to. */
  async listNodes() {
    await this.#connect();
    const nodes = await new Promise((resolve, reject) => {
      const waiter = { resolve, reject };
      this.#pendingList.push(waiter);
      setTimeout(() => {
        const i = this.#pendingList.indexOf(waiter);
        if (i >= 0) {
          this.#pendingList.splice(i, 1);
          reject(new BridgeError('Brigade Bridge did not return its node list in time'));
        }
      }, this.#requestTimeoutMs).unref?.();
      this.#ws.send(JSON.stringify({ type: 'LIST_NODES', payload: {} }));
    });
    return nodes.filter((node) => !Array.isArray(node.capabilities) || node.capabilities.includes('receive_task'));
  }

  get activeJob() {
    return [...this.jobs.values()].find((job) => !TERMINAL.has(job.status) && job.status !== 'unknown');
  }

  async startJob({ nodeId, instruction, projectId }) {
    const active = this.activeJob;
    if (active) {
      throw new BridgeError(`Job ${active.id} is still ${active.status}. Wait for it (bridge_get_result) or cancel it (bridge_cancel) first.`);
    }
    const nodes = await this.listNodes();
    const node = nodes.find((candidate) => candidate.id === nodeId);
    if (!node) {
      const known = nodes.map((candidate) => candidate.id).join(', ') || 'none';
      throw new BridgeError(`"${nodeId}" is not a connected app that can receive tasks. Connected: ${known}`);
    }
    const job = {
      id: `mcp-${randomUUID()}`,
      nodeId,
      nodeName: node.name,
      status: 'starting',
      startedAt: Date.now(),
      updatedAt: Date.now(),
      waiters: [],
    };
    job.startTimer = setTimeout(() => {
      if (job.status === 'starting') {
        this.#update(job, 'failed', { error: 'Brigade Bridge did not start the task. Is the app still connected, and is Bridge stopped?' });
      }
    }, this.#startTimeoutMs);
    job.startTimer.unref?.();
    this.jobs.set(job.id, job);
    // Keep the table small; finished jobs are only needed briefly.
    for (const [id, old] of this.jobs) {
      if (this.jobs.size <= 20) break;
      if (TERMINAL.has(old.status) || old.status === 'unknown') this.jobs.delete(id);
    }
    this.#ws.send(JSON.stringify({
      type: 'RUN_WORKFLOW',
      payload: {
        taskText: instruction,
        targetNodeId: nodeId,
        workflowId: job.id,
        // Marks an outside agent: the daemon must not clear an emergency stop.
        origin: 'external',
        ...(projectId ? { projectId } : {}),
      },
    }));
    return job;
  }

  getJob(jobId) {
    const job = this.jobs.get(jobId);
    if (!job) throw new BridgeError(`Unknown job "${jobId}"`);
    return job;
  }

  /** Resolves when the job finishes or [seconds] pass, whichever is first. */
  waitForJob(job, seconds) {
    if (TERMINAL.has(job.status) || job.status === 'unknown' || !seconds) return Promise.resolve(job);
    return new Promise((resolve) => {
      const timer = setTimeout(() => {
        const i = job.waiters.indexOf(done);
        if (i >= 0) job.waiters.splice(i, 1);
        resolve(job);
      }, seconds * 1000);
      const done = (value) => { clearTimeout(timer); resolve(value); };
      job.waiters.push(done);
    });
  }

  async cancelJob(jobId) {
    const job = this.getJob(jobId);
    if (TERMINAL.has(job.status) || job.status === 'unknown') return job;
    await this.#connect();
    this.#ws.send(JSON.stringify({ type: 'CANCEL_WORKFLOW', payload: {} }));
    return job;
  }

  close() {
    try { this.#ws?.close(); } catch { /* ignore */ }
    this.#ws = null;
    for (const job of this.jobs.values()) clearTimeout(job.startTimer);
  }
}
