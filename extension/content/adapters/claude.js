// Claude adapter — selectors versioned as CLAUDE_V1
(function () {
  const CLAUDE_V1 = {
    composer: 'div[contenteditable="true"][data-placeholder], div[contenteditable="true"]',
    submitBtn: 'button[aria-label="Send message"], button[data-testid="send-button"], button[aria-label="Send Message"]',
    spinner: '[data-testid="streaming-indicator"], .loading-indicator',
    lastResponse: '[data-testid="human-turn"] ~ [data-testid="ai-turn"]:last-of-type, .font-claude-message:last-of-type',
  };

  function identify(url) {
    return url.includes('claude.ai');
  }

  function getComposer() {
    return document.querySelector(CLAUDE_V1.composer);
  }

  function submit(text) {
    const el = getComposer();
    if (!el) throw new Error('CLAUDE_V1: composer not found');
    el.focus();
    // Use execCommand to trigger React synthetic events
    document.execCommand('insertText', false, text);
    setTimeout(() => {
      const btn = document.querySelector(CLAUDE_V1.submitBtn);
      if (btn) btn.click();
    }, 80);
  }

  function isGenerating() {
    return !!document.querySelector(CLAUDE_V1.spinner);
  }

  function getLastResponse() {
    const els = document.querySelectorAll(CLAUDE_V1.lastResponse);
    return els.length ? els[els.length - 1].innerText.trim() : '';
  }

  window.BrigadeAdapters = window.BrigadeAdapters || {};
  window.BrigadeAdapters.claude = {
    identify,
    getComposer,
    submit,
    isGenerating,
    getLastResponse,
  };
})();
