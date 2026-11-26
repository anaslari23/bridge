const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const source = fs.readFileSync('chrome-extension/content.js', 'utf8');
let portMessageHandler;
const sent = [];

class FakeTextArea {
  constructor() { this.value = ''; }
  focus() {}
  matches(selector) { return selector === 'textarea'; }
  dispatchEvent() {}
}

const field = new FakeTextArea();
const realSetInterval = setInterval;
const realClearInterval = clearInterval;
const port = {
  sender: {tab: {id: 7}},
  onMessage: {addListener(handler) { portMessageHandler = handler; }},
  postMessage(message) {
    sent.push(message);
    if (message.type === 'GET_TAB_ID') {
      portMessageHandler({
        type: 'TAB_ID', tabId: 7, windowId: 3,
        title: 'Test Claude', url: 'https://claude.ai/new',
      });
    }
  },
};

const context = {
  console,
  chrome: {runtime: {connect: () => port}},
  HTMLTextAreaElement: class {},
  Event: class {},
  InputEvent: class {},
  KeyboardEvent: class {},
  atob: (value) => Buffer.from(value, 'base64').toString('binary'),
  location: {hostname: 'claude.ai', href: 'https://claude.ai/new'},
  document: {
    title: 'Test Claude',
    body: {innerText: 'initial output'},
    querySelector: (selector) => selector.includes('textarea') ? field : null,
  },
  setTimeout,
  clearTimeout,
  setInterval(callback, delay) {
    if (delay === 10000) return {heartbeat: true};
    return realSetInterval(callback, delay);
  },
  clearInterval(handle) {
    if (handle?.heartbeat) return;
    realClearInterval(handle);
  },
};
context.HTMLTextAreaElement.prototype = {};
Object.defineProperty(context.HTMLTextAreaElement.prototype, 'value', {
  set(value) { field.value = value; },
});

vm.runInNewContext(source, context, {filename: 'content.js'});

const tick = () => new Promise((resolve) => setImmediate(resolve));
const serverMessage = (message) => portMessageHandler(message);

(async () => {
  const registrations = () => sent.filter((message) => message.type === 'BRIDGE_REGISTER');
  assert.equal(registrations().length, 1, 'the content connector registers its tab');
  assert.equal(registrations()[0].payload.adapterId, 'claude-web');
  assert.ok(registrations()[0].payload.capabilities.includes('receive_task'));

  serverMessage({type: 'SEND_TASK', payload: {
    nodeId: 'tab-7', taskId: 'task-1', text: 'hello',
  }});
  await tick();
  assert.equal(sent.at(-1).type, 'BRIDGE_REPORT');
  assert.equal(sent.at(-1).payload.type, 'TASK_ACCEPTED');

  serverMessage({type: 'CANCEL_TASK', payload: {taskId: 'task-1'}});
  assert.equal(sent.at(-1).payload.type, 'TASK_CANCELLED');

  serverMessage({type: 'TAB_ID', tabId: 7, windowId: 4,
    title: 'Test Claude', url: 'https://claude.ai/other'});
  assert.equal(registrations().length, 2,
    'a tab identity change triggers a fresh registration');
  console.log('content connector relay lifecycle passed');
})();
