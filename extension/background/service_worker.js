// Brigade Bridge — service worker
// Connects to the local daemon over WebSocket and routes messages.

const DAEMON_URL = 'ws://localhost:7432';
const IDENTITY_MAP = {
  'chatgpt.com': 'Codex',
  'openai.com': 'Codex',
  'claude.ai': 'Claude',
  'antigravity': 'Anti Gravity',
};

let ws = null;
let connected = false;

function detectIdentity(url) {
  if (!url) return null;
  for (const [pattern, name] of Object.entries(IDENTITY_MAP)) {
    if (url.includes(pattern)) return name;
  }
  return null;
}

function send(type, payload) {
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify({ type, id: crypto.randomUUID(), ts: Date.now(), payload }));
  }
}

function connect() {
  try {
    ws = new WebSocket(DAEMON_URL);

    ws.onopen = () => {
      connected = true;
      chrome.storage.local.set({ bridgeConnected: true });
      // Register all currently open agent tabs
      chrome.tabs.query({}, (tabs) => {
        for (const tab of tabs) {
          if (!tab.url) continue;
          const identity = detectIdentity(tab.url);
          if (identity) registerTab(tab, identity);
        }
      });
    };

    ws.onclose = () => {
      connected = false;
      chrome.storage.local.set({ bridgeConnected: false });
      setTimeout(connect, 3000); // reconnect
    };

    ws.onerror = () => {
      connected = false;
      chrome.storage.local.set({ bridgeConnected: false });
    };

    ws.onmessage = ({ data }) => {
      try {
        const msg = JSON.parse(data);
        if (msg.type === 'SEND_TASK') {
          const { nodeId, taskId, text } = msg.payload;
          // Find tab whose id matches nodeId pattern 'tab-{tabId}'
          const tabId = parseInt(nodeId.replace('tab-', ''), 10);
          if (!isNaN(tabId)) {
            chrome.tabs.sendMessage(tabId, { type: 'SEND_TASK', taskId, text });
          }
        }
        if (msg.type === 'CANCEL') {
          const tabId = parseInt(msg.payload.nodeId.replace('tab-', ''), 10);
          if (!isNaN(tabId)) {
            chrome.tabs.sendMessage(tabId, { type: 'CANCEL' });
          }
        }
      } catch (e) {
        console.error('Failed to parse message from daemon', e);
      }
    };
  } catch (err) {
    connected = false;
    setTimeout(connect, 3000);
  }
}

function registerTab(tab, identity) {
  send('REGISTER_TAB', {
    tabId: tab.id,
    url: tab.url,
    title: tab.title || identity,
    identity,
  });
}

// Tab lifecycle
chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  if (changeInfo.status !== 'complete' || !tab.url) return;
  const identity = detectIdentity(tab.url);
  if (identity) registerTab(tab, identity);
});

chrome.tabs.onRemoved.addListener((tabId) => {
  send('TAB_REMOVED', { tabId });
});

// Messages from content scripts
chrome.runtime.onMessage.addListener((msg, sender) => {
  if (
    msg.type === 'TASK_RESULT' ||
    msg.type === 'ERROR' ||
    msg.type === 'COMPLETION_DETECTED' ||
    msg.type === 'ADAPTER_HEALTH'
  ) {
    send(msg.type, { ...msg.payload, tabId: sender.tab?.id });
  }
});

connect();
