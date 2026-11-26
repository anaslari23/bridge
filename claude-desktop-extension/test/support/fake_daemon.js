import { WebSocketServer } from 'ws';

/** A stand-in for the Brigade Bridge daemon speaking the documented subset. */
export async function startFakeDaemon({ token = 'tok-123', nodes } = {}) {
  const wss = new WebSocketServer({ host: '127.0.0.1', port: 0 });
  await new Promise((resolve) => wss.on('listening', resolve));
  const daemon = {
    url: `ws://127.0.0.1:${wss.address().port}`,
    token,
    received: [],
    sockets: new Set(),
    nodes: nodes ?? [
      { id: 'codex:thr_1', name: 'Codex', kind: 'agent', capabilities: ['receive_task', 'cancel_task'], taskDomains: ['coding'] },
      { id: 'tab-7', name: 'Antigravity tab', kind: 'browser', capabilities: ['receive_task'] },
      { id: 'desktop-1', name: 'Notes', kind: 'desktop', capabilities: ['capture_only'] },
    ],
    /** Override to script what RUN_WORKFLOW does. */
    onRun: (d, payload) => d.status(payload, 'completed', { result: 'done' }),
    send(ws, type, payload = {}) { ws.send(JSON.stringify({ type, payload })); },
    broadcast(type, payload = {}) { for (const ws of daemon.sockets) daemon.send(ws, type, payload); },
    status(payload, status, extra = {}, source = 'user') {
      daemon.broadcast('TASK_STATUS_CHANGED', {
        taskId: 't1', status, workflowId: payload.workflowId, sourceNodeId: source,
        targetNodeId: payload.targetNodeId, instruction: payload.taskText, ...extra,
      });
    },
    async close() {
      for (const ws of daemon.sockets) ws.terminate();
      await new Promise((resolve) => wss.close(resolve));
    },
  };
  wss.on('connection', (ws) => {
    let authed = false;
    daemon.sockets.add(ws);
    ws.on('close', () => daemon.sockets.delete(ws));
    ws.on('message', (raw) => {
      const msg = JSON.parse(raw.toString());
      daemon.received.push(msg);
      if (msg.type === 'AUTHENTICATE') {
        if (msg.payload?.token === daemon.token) { authed = true; daemon.send(ws, 'AUTHENTICATED'); }
        else { daemon.send(ws, 'PROTOCOL_ERROR', { reason: 'Local pairing token was rejected' }); ws.close(); }
        return;
      }
      if (!authed) { daemon.send(ws, 'PROTOCOL_ERROR', { reason: 'Authenticate with the local pairing token first' }); return; }
      if (msg.type === 'LIST_NODES') daemon.send(ws, 'NODE_LIST', { nodes: daemon.nodes });
      if (msg.type === 'RUN_WORKFLOW') daemon.onRun(daemon, msg.payload);
    });
  });
  return daemon;
}
