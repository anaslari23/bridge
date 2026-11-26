(() => {
  const profiles = [
    {
      match: (host) => host === 'claude.ai' || host.endsWith('.claude.ai'),
      adapterId: 'claude-web',
      version: 'v1',
      taskDomains: ['planning', 'general'],
      composers: ['textarea[placeholder*="Message" i]', '[contenteditable="true"]', 'textarea:not([disabled])'],
      responses: ['[data-testid="assistant-turn"]', '[data-testid="ai-turn"]', '[data-is-streaming="false"]'],
      fileInputs: ['input[type="file"]'],
      busy: ['button[aria-label*="Stop" i]', 'button[data-testid*="stop" i]'],
      errors: ['[role="alert"]', '[data-testid*="error" i]'],
    },
    {
      match: (host) => host === 'chatgpt.com' || host.endsWith('.chatgpt.com') ||
        host === 'chat.openai.com',
      adapterId: 'chatgpt-web',
      version: 'v1',
      taskDomains: ['planning', 'coding', 'web_research', 'general'],
      composers: ['#prompt-textarea', 'textarea[data-id="root"]', 'textarea[placeholder*="Message" i]', '[contenteditable="true"]'],
      responses: ['[data-message-author-role="assistant"]', '[data-testid="conversation-turn-assistant"]'],
      fileInputs: ['input[type="file"]'],
      busy: ['button[aria-label*="Stop" i]', 'button[data-testid*="stop" i]'],
      errors: ['[role="alert"]', '[data-testid*="error" i]'],
    },
    {
      match: (host) => host.includes('antigravity') || host.endsWith('.agy.dev'),
      adapterId: 'antigravity-web',
      version: 'v1',
      taskDomains: ['coding', 'general'],
      composers: ['textarea[data-testid="chat-input"]', '.chat-composer textarea', 'textarea:not([disabled])', '[contenteditable="true"]'],
      responses: ['.assistant-message', '[data-role="assistant"]', '.message-bubble.assistant'],
      fileInputs: ['input[type="file"]'],
      busy: ['.generating-indicator', '[data-testid*="loading" i]', '.spinner', 'button[aria-label*="Stop" i]'],
      errors: ['[role="alert"]', '[data-testid*="error" i]'],
    },
  ];
  const profile = profiles.find((candidate) => candidate.match(location.hostname)) || {
    adapterId: 'generic-browser', version: 'v1',
    taskDomains: ['web_research'],
    webResearch: true,
    composers: ['textarea:not([disabled])', '[contenteditable="true"]'],
    responses: [],
    fileInputs: ['input[type="file"]'],
    busy: ['[aria-label*="Stop" i]', 'button[data-testid*="stop" i]'],
    errors: ['[role="alert"]', '[data-testid*="error" i]'],
  };

  const port = chrome.runtime.connect({name: 'bridge'});
  let tabId;
  let windowId;
  let heartbeatTimer;
  let registeredUrl;
  const activeTasks = new Map();

  port.onMessage.addListener((message) => {
    if (message.type === 'TAB_ID') {
      const firstIdentity = tabId == null;
      const identityChanged = !firstIdentity &&
        (windowId !== message.windowId || registeredUrl !== message.url);
      tabId = message.tabId;
      windowId = message.windowId;
      if (firstIdentity || identityChanged) registerTab();
      if (!heartbeatTimer) {
        heartbeatTimer = setInterval(() => {
          port.postMessage({type: 'GET_TAB_ID'});
          port.postMessage({type: 'BRIDGE_HEARTBEAT', payload: {
            tabId, windowId, title: document.title, url: location.href,
          }});
          if (registeredUrl !== location.href) registerTab();
        }, 10000);
      }
      return;
    }
    if (message.type === 'SEND_TASK' && message.payload.nodeId === `tab-${tabId}`) {
      executeTask(message.payload);
    }
    if (message.type === 'INSPECT_TAB' && message.payload.nodeId === `tab-${tabId}`) {
      inspectTab(message.payload.requestId);
    }
    if (message.type === 'WEB_RESEARCH_REQUEST' &&
        message.payload.nodeId === `tab-${tabId}` && profile.webResearch) {
      reportWebResearch(message.payload);
    }
    if (message.type === 'CANCEL_TASK') cancelTask(message.payload.taskId);
    if (message.type === 'STOP_ALL') [...activeTasks.keys()].forEach(cancelTask);
  });

  function registerTab() {
    if (tabId == null) return;
    registeredUrl = location.href;
    port.postMessage({type: 'BRIDGE_REGISTER', payload: {
      tabId, windowId, title: document.title, url: registeredUrl,
      identity: document.title || location.hostname,
      adapterId: profile.adapterId, adapterVersion: profile.version,
      capabilities: profile.webResearch
        ? ['read_text', 'send_text', 'receive_task', 'web_research']
        : ['read_text', 'send_text', 'receive_task'],
      taskDomains: profile.taskDomains,
    }});
  }

  function composer() {
    return profile.composers.map((selector) => document.querySelector(selector)).find(Boolean);
  }

  function latestResponse() {
    if (typeof document.querySelectorAll !== 'function') return '';
    const elements = profile.responses
      .flatMap((selector) => Array.from(document.querySelectorAll(selector)))
      .filter((element) => element.innerText?.trim());
    return elements.length ? elements.at(-1).innerText.trim() : '';
  }

  function setComposer(text) {
    const field = composer();
    if (!field) return false;
    field.focus();
    if (field.matches('textarea')) {
      const setter = Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value').set;
      setter.call(field, text);
      field.dispatchEvent(new Event('input', {bubbles: true}));
    } else {
      field.textContent = text;
      field.dispatchEvent(new InputEvent('input', {bubbles: true, inputType: 'insertText', data: text}));
    }
    return true;
  }

  async function executeTask({taskId, text, attachments = [], contextNodeIds = []}) {
    if (activeTasks.has(taskId)) return report('ERROR', taskId, 'Duplicate task ID is already running');
    const taskUrl = location.href;
    const baseline = document.body.innerText.slice(-12000);
    if (!(await attachFiles(attachments))) {
      return report('ERROR', taskId, 'This page does not expose a supported file upload control');
    }
    const contextHint = contextNodeIds.length > 0
      ? `\n\n[Brigade Bridge context nodes: ${contextNodeIds.join(', ')}]` : '';
    const attachmentHint = attachments.length > 0
      ? `\n\n[Brigade Bridge attached: ${attachments.map((item) => item.name).join(', ')}]` : '';
    if (!setComposer(`${text}${contextHint}${attachmentHint}`)) return report('ERROR', taskId, 'No supported composer found');
    composer().dispatchEvent(new KeyboardEvent('keydown', {key: 'Enter', code: 'Enter', bubbles: true}));
    report('TASK_ACCEPTED', taskId);
    waitForStableOutput(taskId, taskUrl, baseline);
  }

  async function attachFiles(attachments) {
    if (!attachments || attachments.length === 0) return true;
    const input = profile.fileInputs.map((selector) => document.querySelector(selector)).find(Boolean);
    if (!input) return false;
    const transfer = new DataTransfer();
    try {
      for (const attachment of attachments) {
        if (!attachment.dataBase64) return false;
        const binary = atob(attachment.dataBase64);
        const bytes = Uint8Array.from(binary, (character) => character.charCodeAt(0));
        transfer.items.add(new File([bytes], attachment.name, {
          type: attachment.mimeType || 'application/octet-stream'
        }));
      }
      input.files = transfer.files;
      input.dispatchEvent(new Event('input', {bubbles: true}));
      input.dispatchEvent(new Event('change', {bubbles: true}));
      return true;
    } catch (_) { return false; }
  }

  function waitForStableOutput(taskId, taskUrl, baseline) {
    const baselineResponse = latestResponse();
    let previous = baselineResponse || baseline; let stable = 0; let sawActivity = false; let finished = false;
    const timer = setInterval(() => {
      if (location.href !== taskUrl) return finish('ERROR', 'Tab URL changed while task was running');
      const output = document.body.innerText.slice(-12000);
      const response = latestResponse();
      const busy = profile.busy.some((selector) => document.querySelector(selector));
      const error = profile.errors.some((selector) => document.querySelector(selector));
      if (error && sawActivity) return finish('ERROR', 'Adapter reported an error state');
      const current = response || output;
      const changed = response ? response !== baselineResponse : output !== baseline;
      if (busy || changed) sawActivity = true;
      if (sawActivity && current === previous && !busy) stable += 1; else stable = 0;
      previous = current;
      if (sawActivity && stable >= 3) {
        const result = response || (output.startsWith(baseline) ? output.slice(baseline.length).trim() : output);
        finish('TASK_RESULT', result || output);
      }
    }, 1000);
    const timeout = setTimeout(() => { if (!finished) finish('ERROR', 'Completion timeout'); }, 120000);
    activeTasks.set(taskId, {timer, timeout});

    function finish(type, output) {
      if (finished) return;
      finished = true;
      clearInterval(timer);
      clearTimeout(timeout);
      activeTasks.delete(taskId);
      report(type, taskId, output);
    }
  }

  function cancelTask(taskId) {
    const state = activeTasks.get(taskId);
    if (!state) return;
    const stopButton = profile.busy.map((selector) => document.querySelector(selector)).find(Boolean);
    if (stopButton && typeof stopButton.click === 'function') stopButton.click();
    clearInterval(state.timer);
    clearTimeout(state.timeout);
    activeTasks.delete(taskId);
    report('TASK_CANCELLED', taskId, 'Cancelled by user');
  }

  function inspectTab(requestId) {
    report('TAB_INSPECTION', requestId, document.body.innerText.slice(-12000));
  }

  function reportWebResearch({requestId, query}) {
    const sources = Array.from(document.querySelectorAll('a[href]'))
      .map((link) => ({
        title: (link.innerText || link.textContent || '').trim().slice(0, 200),
        url: link.href,
      }))
      .filter((source) => {
        try {
          return source.title && /^https?:$/.test(new URL(source.url).protocol);
        } catch (_) { return false; }
      })
      .filter((source, index, all) =>
        all.findIndex((candidate) => candidate.url === source.url) === index)
      .slice(0, 30);
    port.postMessage({type: 'BRIDGE_REPORT', payload: {
      type: 'WEB_RESEARCH_RESULT',
      requestId,
      query: String(query || '').slice(0, 1000),
      pageText: String(document.body.innerText || '').slice(-12000),
      sources,
    }});
  }

  function report(type, taskId, output) {
    port.postMessage({type: 'BRIDGE_REPORT', payload: {type, taskId, output}});
  }

  port.postMessage({type: 'GET_TAB_ID'});
})();
