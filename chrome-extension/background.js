const ports = new Map();
const sessions = new Map();
const RETRY_DELAY_MS = 1500;
const HEARTBEAT_MS = 10000;
const STORAGE_KEY = 'connectedTabIds';

function adapterForUrl(url) {
  try {
    const host = new URL(url).hostname;
    if (host === 'claude.ai' || host.endsWith('.claude.ai')) return 'claude-web';
    if (host === 'chatgpt.com' || host.endsWith('.chatgpt.com') ||
        host === 'chat.openai.com') return 'chatgpt-web';
    if (host.includes('antigravity') || host.endsWith('.agy.dev')) {
      return 'antigravity-web';
    }
  } catch (_) {}
  return 'generic-browser';
}

function taskDomainsForAdapter(adapterId) {
  if (adapterId === 'claude-web') return ['planning', 'general'];
  if (adapterId === 'chatgpt-web') return ['planning', 'coding', 'web_research', 'general'];
  if (adapterId === 'antigravity-web') return ['coding', 'general'];
  return ['web_research'];
}

function capabilitiesForAdapter(adapterId) {
  const capabilities = ['read_text', 'send_text', 'receive_task'];
  if (adapterId === 'generic-browser') capabilities.push('web_research');
  return capabilities;
}

function isSupportedTab(tab) {
  return typeof tab?.id === 'number' &&
      typeof tab.url === 'string' && tab.url.startsWith('https://');
}

async function connectedTabIds() {
  const stored = await chrome.storage.local.get(STORAGE_KEY);
  return Array.isArray(stored[STORAGE_KEY]) ? stored[STORAGE_KEY] : [];
}

async function isConnected(tabId) {
  return (await connectedTabIds()).includes(tabId);
}

async function setConnected(tabId, connected) {
  const ids = new Set(await connectedTabIds());
  if (connected) ids.add(tabId);
  else ids.delete(tabId);
  await chrome.storage.local.set({[STORAGE_KEY]: [...ids]});
}

function sendToSocket(tabId, type, payload = {}) {
  const session = sessions.get(tabId);
  if (!session || session.socket.readyState !== WebSocket.OPEN ||
      !session.authenticated) return false;
  session.socket.send(JSON.stringify({type, payload}));
  return true;
}

async function token() {
  try {
    const stored = await chrome.storage.local.get('bridgeToken');
    return typeof stored.bridgeToken === 'string' ? stored.bridgeToken : '';
  } catch (_) {
    return '';
  }
}

function forwardToTab(tabId, message) {
  const port = ports.get(tabId);
  if (!port) return false;
  try {
    port.postMessage(message);
    return true;
  } catch (_) {
    ports.delete(tabId);
    return false;
  }
}

function registerPayload(tab) {
  const url = tab.url || '';
  return {
    tabId: tab.id,
    windowId: tab.windowId,
    title: tab.title || '',
    url,
    identity: tab.title || new URL(url).hostname,
    adapterId: adapterForUrl(url),
    adapterVersion: 'v1',
    capabilities: capabilitiesForAdapter(adapterForUrl(url)),
    taskDomains: taskDomainsForAdapter(adapterForUrl(url)),
  };
}

function closeSession(tabId) {
  const session = sessions.get(tabId);
  if (!session) return;
  clearInterval(session.heartbeat);
  clearTimeout(session.retry);
  try { session.socket.close(); } catch (_) {}
  sessions.delete(tabId);
}

function scheduleReconnect(tabId) {
  const session = sessions.get(tabId);
  if (!session || session.retry != null) return;
  session.retry = setTimeout(() => {
    const current = sessions.get(tabId);
    if (current) current.retry = null;
    ensureSession(tabId);
  }, RETRY_DELAY_MS);
}

async function refreshSession(tabId) {
  if (!(await isConnected(tabId))) return;
  try {
    const tab = await chrome.tabs.get(tabId);
    if (!isSupportedTab(tab)) {
      const session = sessions.get(tabId);
      if (session?.authenticated) sendToSocket(tabId, 'TAB_REMOVED', {tabId});
      closeSession(tabId);
      return;
    }
    const session = sessions.get(tabId);
    if (session) session.tab = tab;
  } catch (_) {
    closeSession(tabId);
  }
}

async function ensureSession(tabId, initialTab) {
  if (!(await isConnected(tabId))) return;
  let tab = initialTab;
  if (!tab) {
    try { tab = await chrome.tabs.get(tabId); } catch (_) { return; }
  }
  if (!isSupportedTab(tab)) return;
  const existing = sessions.get(tabId);
  if (existing && (existing.socket.readyState === WebSocket.OPEN ||
      existing.socket.readyState === WebSocket.CONNECTING)) {
    existing.tab = tab;
    return;
  }
  if (existing) closeSession(tabId);

  const socket = new WebSocket('ws://127.0.0.1:7432');
  const session = {
    socket,
    tab,
    authenticated: false,
    registeredUrl: null,
    registeredWindowId: null,
    heartbeat: null,
    retry: null,
  };
  sessions.set(tabId, session);
  socket.addEventListener('open', async () => {
    socket.send(JSON.stringify({type: 'AUTHENTICATE', payload: {token: await token()}}));
  });
  socket.addEventListener('message', async (event) => {
    let message;
    try { message = JSON.parse(event.data); } catch (_) { return; }
    if (message.type === 'AUTHENTICATED') {
      if (!(await isConnected(tabId)) || sessions.get(tabId) !== session) {
        closeSession(tabId);
        return;
      }
      session.authenticated = true;
      const payload = registerPayload(session.tab);
      session.registeredUrl = payload.url;
      session.registeredWindowId = payload.windowId;
      sendToSocket(tabId, 'REGISTER_TAB', payload);
      forwardToTab(tabId, {type: 'BRIDGE_CONNECTED'});
      clearInterval(session.heartbeat);
      session.heartbeat = setInterval(() => {
        refreshSession(tabId).then(() => {
          const current = sessions.get(tabId);
          if (!current || !current.authenticated) return;
          const payload = registerPayload(current.tab);
          const identityChanged = current.registeredUrl !== payload.url ||
              current.registeredWindowId !== payload.windowId;
          if (identityChanged) {
            current.registeredUrl = payload.url;
            current.registeredWindowId = payload.windowId;
            sendToSocket(tabId, 'REGISTER_TAB', payload);
          } else {
            sendToSocket(tabId, 'HEARTBEAT', payload);
          }
        });
      }, HEARTBEAT_MS);
      return;
    }
    if (message.type === 'SEND_TASK' || message.type === 'INSPECT_TAB' ||
        message.type === 'CANCEL_TASK' || message.type === 'STOP_ALL') {
      forwardToTab(tabId, message);
    }
  });
  socket.addEventListener('close', () => {
    const current = sessions.get(tabId);
    if (current?.socket !== socket) return;
    clearInterval(session.heartbeat);
    session.authenticated = false;
    scheduleReconnect(tabId);
  });
  socket.addEventListener('error', () => {});
}

async function connectTab(tabId) {
  let tab;
  try { tab = await chrome.tabs.get(tabId); } catch (_) {
    return {ok: false, error: 'This tab is no longer available.'};
  }
  if (!isSupportedTab(tab)) {
    return {ok: false, error: 'Connect a secure web page.'};
  }
  if (!(await token())) {
    return {ok: false, error: 'Add the local pairing token in extension options.'};
  }
  await setConnected(tabId, true);
  await ensureSession(tabId, tab);
  try {
    await chrome.scripting.executeScript({target: {tabId}, files: ['content.js']});
  } catch (_) {
    await setConnected(tabId, false);
    closeSession(tabId);
    return {ok: false, error: 'This page does not allow the connector.'};
  }
  return {ok: true};
}

async function disconnectTab(tabId) {
  await setConnected(tabId, false);
  sendToSocket(tabId, 'TAB_REMOVED', {tabId});
  closeSession(tabId);
  const port = ports.get(tabId);
  if (port) {
    try { port.disconnect(); } catch (_) {}
    ports.delete(tabId);
  }
  return {ok: true};
}

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message?.type === 'CONNECT_TAB' && Number.isInteger(message.tabId)) {
    connectTab(message.tabId).then(sendResponse);
    return true;
  }
  if (message?.type === 'DISCONNECT_TAB' && Number.isInteger(message.tabId)) {
    disconnectTab(message.tabId).then(sendResponse);
    return true;
  }
});

chrome.runtime.onConnect.addListener((port) => {
  if (port.name !== 'bridge') return;
  const tabId = port.sender?.tab?.id;
  if (typeof tabId !== 'number') return;
  isConnected(tabId).then((connected) => {
    if (!connected) {
      port.disconnect();
      return;
    }
    ports.set(tabId, port);
    ensureSession(tabId, port.sender.tab);
    port.onMessage.addListener((message) => {
      if (!ports.has(tabId) || ports.get(tabId) !== port) return;
      if (message.type === 'GET_TAB_ID') {
        chrome.tabs.get(tabId).then((tab) => {
          port.postMessage({
            type: 'TAB_ID', tabId: tab.id, windowId: tab.windowId,
            title: tab.title || '', url: tab.url || '',
          });
        }).catch(() => {});
        return;
      }
      if (message.type === 'BRIDGE_REGISTER') {
        sendToSocket(tabId, 'REGISTER_TAB', {
          ...message.payload, tabId,
          adapterVersion: message.payload?.adapterVersion || 'v1',
        });
        return;
      }
      if (message.type === 'BRIDGE_HEARTBEAT') {
        sendToSocket(tabId, 'HEARTBEAT', {...message.payload, tabId});
        return;
      }
      if (message.type === 'BRIDGE_REPORT') {
        const report = message.payload || {};
        const {type, ...payload} = report;
        sendToSocket(tabId, type, payload);
      }
    });
    port.onDisconnect.addListener(() => {
      if (ports.get(tabId) === port) ports.delete(tabId);
    });
  });
});

chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  if (changeInfo.status !== 'complete' && !changeInfo.url) return;
  isConnected(tabId).then((connected) => {
    if (!connected) return;
    ensureSession(tabId, tab).then(async () => {
      if (changeInfo.status === 'complete' && isSupportedTab(tab)) {
        try {
          await chrome.scripting.executeScript({target: {tabId}, files: ['content.js']});
        } catch (_) {}
      }
      if (!changeInfo.url) return;
      const session = sessions.get(tabId);
      if (!session?.authenticated || !isSupportedTab(tab)) return;
      const payload = registerPayload(tab);
      session.registeredUrl = payload.url;
      session.registeredWindowId = payload.windowId;
      sendToSocket(tabId, 'REGISTER_TAB', payload);
    });
  });
});

chrome.tabs.onRemoved.addListener((tabId) => {
  isConnected(tabId).then((connected) => {
    if (connected) disconnectTab(tabId);
  });
});

connectedTabIds().then(async (ids) => {
  for (const tabId of ids) {
    try {
      const tab = await chrome.tabs.get(tabId);
      if (!isSupportedTab(tab)) continue;
      await ensureSession(tabId, tab);
      await chrome.scripting.executeScript({target: {tabId}, files: ['content.js']});
    } catch (_) {
      await disconnectTab(tabId);
    }
  }
}).catch(() => {});
