const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

let receive;
const sent = [];
const field = {
  focus() {},
  matches: (selector) => selector === 'textarea',
  dispatchEvent() {},
};
const port = {
  sender: {tab: {id: 21}},
  onMessage: {addListener(handler) { receive = handler; }},
  postMessage(message) {
    sent.push(message);
    if (message.type === 'GET_TAB_ID') {
      receive({
        type: 'TAB_ID',
        tabId: 21,
        windowId: 4,
        title: 'Search results',
        url: 'https://www.google.com/search?q=bridge',
      });
    }
  },
};
const sourceLink = {
  href: 'https://example.com/source',
  innerText: 'Example source',
  textContent: 'Example source',
};
const context = {
  console,
  chrome: {runtime: {connect: () => port}},
  URL,
  HTMLTextAreaElement: class {},
  Event: class {},
  InputEvent: class {},
  KeyboardEvent: class {},
  atob: (value) => Buffer.from(value, 'base64').toString('binary'),
  location: {
    hostname: 'www.google.com',
    href: 'https://www.google.com/search?q=bridge',
  },
  document: {
    title: 'Search results',
    body: {innerText: 'Visible search result text'},
    querySelector: (selector) => selector.includes('textarea') ? field : null,
    querySelectorAll: (selector) => selector === 'a[href]' ? [sourceLink] : [],
  },
  setTimeout,
  clearTimeout,
  setInterval: () => ({heartbeat: true}),
  clearInterval: () => {},
};
context.HTMLTextAreaElement.prototype = {};
Object.defineProperty(context.HTMLTextAreaElement.prototype, 'value', {
  set() {},
});
vm.runInNewContext(fs.readFileSync('chrome-extension/content.js', 'utf8'), context);

const tick = () => new Promise((resolve) => setImmediate(resolve));

(async () => {
  receive({type: 'WEB_RESEARCH_REQUEST', payload: {
    nodeId: 'tab-22', requestId: 'wrong-tab', query: 'bridge search',
  }});
  await tick();
  assert.equal(sent.some((message) =>
    message.payload?.requestId === 'wrong-tab'), false,
  'a research request for another tab is ignored');

  receive({type: 'WEB_RESEARCH_REQUEST', payload: {
    nodeId: 'tab-21', requestId: 'research-1', query: 'bridge search',
  }});
  await tick();
  const result = sent.find((message) =>
    message.payload?.type === 'WEB_RESEARCH_RESULT');
  assert.ok(result, 'the connected page returns a correlated research result');
  assert.equal(result.payload.requestId, 'research-1');
  assert.equal(result.payload.query, 'bridge search');
  assert.match(result.payload.pageText, /Visible search result text/);
  assert.deepEqual(
    JSON.parse(JSON.stringify(result.payload.sources)),
    [{title: 'Example source', url: 'https://example.com/source'}],
  );
  console.log('connected-tab web research correlation passed');
})().catch((error) => { console.error(error); process.exitCode = 1; });
