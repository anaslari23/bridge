// Bridge content script — routes SEND_TASK to the correct adapter,
// runs the completion state machine, sends TASK_RESULT back.

(function () {
  function getAdapter() {
    const adapters = Object.values(window.BrigadeAdapters || {});
    return adapters.find((a) => a.identify(location.href)) ?? null;
  }

  // State machine
  const State = {
    IDLE: 'idle',
    COMPOSING: 'composing',
    SUBMITTED: 'submitted',
    GENERATING: 'generating',
    STABLE: 'stable',
    DONE: 'done',
  };

  let state = State.IDLE;
  let currentTaskId = null;
  let stabilityTimer = null;
  let urlAtStart = null;
  let cancelled = false;

  function guardUrl() {
    if (location.href !== urlAtStart) {
      reportError('Tab navigated away during task');
      return false;
    }
    return true;
  }

  function reportError(reason) {
    chrome.runtime.sendMessage({
      type: 'ERROR',
      payload: { taskId: currentTaskId, reason },
    });
    reset();
  }

  function reset() {
    state = State.IDLE;
    currentTaskId = null;
    urlAtStart = null;
    cancelled = false;
    if (stabilityTimer) {
      clearTimeout(stabilityTimer);
      stabilityTimer = null;
    }
  }

  function waitForStable(adapter, resolve) {
    if (cancelled || !guardUrl()) return;
    if (adapter.isGenerating()) {
      state = State.GENERATING;
      if (stabilityTimer) clearTimeout(stabilityTimer);
      stabilityTimer = null;
      setTimeout(() => waitForStable(adapter, resolve), 300);
      return;
    }
    // Not generating — start 1.5 s stability window
    if (!stabilityTimer) {
      stabilityTimer = setTimeout(() => {
        if (cancelled || !guardUrl()) return;
        state = State.STABLE;
        const text = adapter.getLastResponse();
        chrome.runtime.sendMessage({
          type: 'TASK_RESULT',
          payload: { taskId: currentTaskId, output: text, status: 'completed' },
        });
        reset();
        resolve();
      }, 1500);
    }
    setTimeout(() => waitForStable(adapter, resolve), 300);
  }

  chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
    if (msg.type === 'CANCEL') {
      cancelled = true;
      reset();
      sendResponse({ ok: true });
      return;
    }

    if (msg.type === 'SEND_TASK') {
      if (state !== State.IDLE) {
        sendResponse({ ok: false, reason: 'busy' });
        return;
      }

      const adapter = getAdapter();
      if (!adapter) {
        chrome.runtime.sendMessage({
          type: 'ERROR',
          payload: { taskId: msg.taskId, reason: 'No adapter for this URL' },
        });
        sendResponse({ ok: false });
        return;
      }

      const composer = adapter.getComposer();
      if (!composer) {
        chrome.runtime.sendMessage({
          type: 'ADAPTER_HEALTH',
          payload: { health: 'requires_update', reason: 'composer not found' },
        });
        sendResponse({ ok: false });
        return;
      }

      currentTaskId = msg.taskId;
      urlAtStart = location.href;
      state = State.COMPOSING;

      try {
        adapter.submit(msg.text);
        state = State.SUBMITTED;
      } catch (e) {
        reportError(e.message);
        sendResponse({ ok: false });
        return;
      }

      new Promise((resolve) => {
        // Give submit a moment then start watching
        setTimeout(() => waitForStable(adapter, resolve), 500);
      });

      sendResponse({ ok: true });
    }
  });
})();
