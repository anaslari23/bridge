const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const manifest = JSON.parse(fs.readFileSync('chrome-extension/manifest.json', 'utf8'));
assert.equal(manifest.content_scripts, undefined,
  'tabs must not receive a content script before the user connects them');
assert.ok(manifest.action.default_popup,
  'the extension action must open the explicit connection controls');

const backgroundSource = fs.readFileSync('chrome-extension/background.js', 'utf8');
assert.doesNotMatch(backgroundSource, /chrome\.tabs\.query\(\s*\{\s*\}\s*\)/,
  'the service worker must not enumerate every tab');
assert.match(backgroundSource, /TAB_REMOVED/,
  'disconnect must tell the daemon to remove the connected tab');

const listeners = () => ({
  callback: null,
  addListener(callback) { this.callback = callback; },
});
const socketMessages = [];
const sockets = [];
const injected = [];
const storageData = {bridgeToken: 'local-token'};
const tab = {id: 7, windowId: 2, title: 'Current Claude', url: 'https://claude.ai/new'};
const runtimeMessage = listeners();
class FakeWebSocket {
  static CONNECTING = 0;
  static OPEN = 1;
  constructor() {
    this.readyState = FakeWebSocket.CONNECTING;
    this.handlers = {};
    sockets.push(this);
  }
  addEventListener(type, callback) { this.handlers[type] = callback; }
  send(raw) {
    const message = JSON.parse(raw);
    socketMessages.push(message);
  }
  close() { this.readyState = 3; }
  emit(type, data) { this.handlers[type]?.(data); }
}

const chrome = {
  runtime: {
    onMessage: runtimeMessage,
    onConnect: listeners(),
  },
  tabs: {
    get: async (tabId) => tabId === tab.id ? tab : null,
    query: async () => { throw new Error('All-tab queries are forbidden'); },
    onUpdated: listeners(),
    onRemoved: listeners(),
  },
  scripting: {executeScript: async (options) => { injected.push(options); }},
  storage: {
    local: {
      get: async (key) => key ? {[key]: storageData[key]} : {...storageData},
      set: async (values) => Object.assign(storageData, values),
    },
  },
};
vm.runInNewContext(backgroundSource, {
  chrome,
  WebSocket: FakeWebSocket,
  URL,
  setTimeout,
  clearTimeout,
  setInterval: () => 1,
  clearInterval: () => {},
  console,
});

async function userAction(message) {
  return new Promise((resolve) => runtimeMessage.callback(message, {}, resolve));
}

(async () => {
  const connected = await userAction({type: 'CONNECT_TAB', tabId: tab.id});
  assert.equal(connected.ok, true);
  assert.equal(JSON.stringify(injected),
    JSON.stringify([{target: {tabId: 7}, files: ['content.js']} ]));
  assert.equal(storageData.connectedTabIds.includes(7), true);
  assert.equal(sockets.length, 1, 'only the user-selected tab opens a connector');

  sockets[0].readyState = FakeWebSocket.OPEN;
  sockets[0].emit('open');
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(socketMessages.at(-1).type, 'AUTHENTICATE');
  sockets[0].emit('message', {data: JSON.stringify({type: 'AUTHENTICATED'})});
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(socketMessages.at(-1).type, 'REGISTER_TAB');

  const disconnected = await userAction({type: 'DISCONNECT_TAB', tabId: tab.id});
  assert.equal(disconnected.ok, true);
  assert.equal(storageData.connectedTabIds.includes(7), false);
  assert.equal(socketMessages.at(-1).type, 'TAB_REMOVED');

  await userAction({type: 'CONNECT_TAB', tabId: tab.id});
  const registerCount = socketMessages.filter((message) =>
    message.type === 'REGISTER_TAB').length;
  await userAction({type: 'DISCONNECT_TAB', tabId: tab.id});
  sockets[1].readyState = FakeWebSocket.OPEN;
  sockets[1].emit('open');
  await new Promise((resolve) => setImmediate(resolve));
  sockets[1].emit('message', {data: JSON.stringify({type: 'AUTHENTICATED'})});
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(socketMessages.filter((message) =>
    message.type === 'REGISTER_TAB').length, registerCount,
  'a delayed authentication must not restore a tab after explicit disconnect');

  const popupHandlers = {};
  const popupElements = new Map(['#connect', '#disconnect', '#tab-name', '#status']
    .map((selector) => [selector, {
      hidden: false,
      textContent: '',
      addEventListener(type, handler) { popupHandlers[`${selector}:${type}`] = handler; },
    }]));
  const activeQueries = [];
  const popupMessages = [];
  vm.runInNewContext(fs.readFileSync('chrome-extension/popup.js', 'utf8'), {
    document: {querySelector: (selector) => popupElements.get(selector)},
    chrome: {
      tabs: {query: async (query) => {
        activeQueries.push(query);
        return [tab];
      }},
      storage: {local: {get: async () => ({connectedTabIds: []})}},
      runtime: {sendMessage: async (message) => {
        popupMessages.push(message);
        return {ok: true};
      }},
    },
  });
  await new Promise((resolve) => setImmediate(resolve));
  await popupHandlers['#connect:click']();
  assert.ok(activeQueries.every((query) =>
    query.active === true && query.currentWindow === true));
  assert.equal(JSON.stringify(popupMessages[0]),
    JSON.stringify({type: 'CONNECT_TAB', tabId: 7}));
  console.log('explicit tab pairing lifecycle passed');
})().catch((error) => { console.error(error); process.exitCode = 1; });

