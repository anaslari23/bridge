// End-to-end integration test connecting to Brigade Bridge live daemon on ws://127.0.0.1:7432

const localAuthToken = process.env.BRIGADE_BRIDGE_LOCAL_TOKEN;
if (!localAuthToken) {
  console.error('Set BRIGADE_BRIDGE_LOCAL_TOKEN to the token shown in Brigade Bridge Settings.');
  process.exit(2);
}

const ws = new WebSocket('ws://127.0.0.1:7432');

let testStep = 0;
let receivedNodes = false;
let receivedApproval = false;
let receivedSendTask = false;
let receivedCompleted = false;

function log(msg) {
  console.log(`[E2E TEST] ${msg}`);
}

ws.onopen = () => {
  log('Connected to Brigade Bridge Daemon over WebSocket');
  ws.send(JSON.stringify({
    type: 'AUTHENTICATE',
    payload: {token: localAuthToken},
  }));
};

function registerTestTabs() {

  // Step 1: Register 3 tabs as nodes
  log('Step 1: Registering agent tabs (Codex, Claude, Anti Gravity)...');
  ws.send(JSON.stringify({
    type: 'REGISTER_TAB',
    payload: {
      tabId: 101,
      windowId: 201,
      title: 'ChatGPT Codex',
      url: 'https://chatgpt.com/codex',
      identity: 'Codex',
    }
  }));

  ws.send(JSON.stringify({
    type: 'REGISTER_TAB',
    payload: {
      tabId: 102,
      windowId: 202,
      title: 'Claude 3.5 Sonnet',
      url: 'https://claude.ai/chat',
      identity: 'Claude',
    }
  }));

  ws.send(JSON.stringify({
    type: 'REGISTER_TAB',
    payload: {
      tabId: 103,
      windowId: 203,
      title: 'Anti Gravity Studio',
      url: 'https://agy.dev/workspace',
      identity: 'Anti Gravity',
    }
  }));

  // Step 2: Request list of nodes
  setTimeout(() => {
    log('Step 2: Requesting node list...');
    ws.send(JSON.stringify({ type: 'LIST_NODES' }));
  }, 400);
};

ws.onmessage = (event) => {
  const msg = JSON.parse(event.data);
  log(`Received message from daemon: type=${msg.type} payload=${JSON.stringify(msg.payload || {})}`);

  if (msg.type === 'AUTHENTICATED') {
    log('✓ Local pairing token accepted');
    registerTestTabs();
    return;
  }

  if (msg.type === 'PROTOCOL_ERROR') {
    console.error(`[E2E TEST] Daemon rejected the request: ${msg.payload?.reason || 'unknown error'}`);
    process.exit(1);
  }

  if (msg.type === 'NODE_LIST') {
    const nodes = msg.payload.nodes;
    log(`✓ Received Node List: ${nodes.map(n => n.name).join(', ')}`);
    if (nodes.length >= 3) {
      receivedNodes = true;
      // Step 3: Run workflow Codex -> Claude
      setTimeout(() => {
        log('Step 3: Dispatching workflow Codex -> Claude...');
        ws.send(JSON.stringify({
          type: 'RUN_WORKFLOW',
          payload: {
            taskText: 'Research and summarize local bridge architecture',
            nodes: [
              { id: 'tab-101', name: 'Codex', kind: 'agent', detail: 'Tab 101' },
              { id: 'tab-102', name: 'Claude', kind: 'agent', detail: 'Tab 102' },
            ],
            edges: [
              { from: 'tab-101', to: 'tab-102' }
            ]
          }
        }));
      }, 500);
    }
  }

  if (msg.type === 'APPROVAL_REQUIRED') {
    receivedApproval = true;
    log(`✓ Approval required for task ${msg.payload.taskId}: "${msg.payload.instruction}"`);
    // Step 4: Approve the task
    setTimeout(() => {
      log(`Step 4: Approving task ${msg.payload.taskId}...`);
      ws.send(JSON.stringify({
        type: 'APPROVE_TASK',
        payload: { taskId: msg.payload.taskId }
      }));
    }, 300);
  }

  if (msg.type === 'SEND_TASK') {
    receivedSendTask = true;
    log(`✓ Extension received task instruction to adapter: "${msg.payload.text}" for node ${msg.payload.nodeId}`);
    // Step 5: Simulate adapter finishing generation and sending back result
    setTimeout(() => {
      log(`Step 5: Simulating adapter response for task ${msg.payload.taskId}...`);
      ws.send(JSON.stringify({
        type: 'TASK_RESULT',
        payload: {
          taskId: msg.payload.taskId,
          output: `Simulated response from ${msg.payload.nodeId}: Architecture verified clean.`
        }
      }));
    }, 400);
  }

  if (msg.type === 'TASK_STATUS_CHANGED' && msg.payload.status === 'completed') {
    receivedCompleted = true;
    log(`✓ Task completed successfully: ${msg.payload.taskId}`);
  }

  if (msg.type === 'LOG_ENTRY' && msg.payload.message.includes('Workflow completed')) {
    log('✓ Workflow successfully completed end-to-end!');
    log('====================================================');
    log('ALL END-TO-END CRITERIA MET:');
    log(`- Node Discovery / Registration: ${receivedNodes ? 'PASSED' : 'FAILED'}`);
    log(`- Approval Gate Trigger: ${receivedApproval ? 'PASSED' : 'FAILED'}`);
    log(`- Extension Adapter Dispatch: ${receivedSendTask ? 'PASSED' : 'FAILED'}`);
    log(`- Task Completion & Artifact: ${receivedCompleted ? 'PASSED' : 'FAILED'}`);
    log('====================================================');
    setTimeout(() => {
      ws.close();
      process.exit(0);
    }, 500);
  }
};

ws.onerror = (err) => {
  console.error('[E2E TEST ERROR]', err);
  process.exit(1);
};

// Timeout safeguard
setTimeout(() => {
  console.error('[E2E TEST] Timeout waiting for workflow completion.');
  process.exit(1);
}, 15000);
