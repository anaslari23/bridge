// Codex (ChatGPT) adapter — selectors versioned as CODEX_V1
(function () {
  const CODEX_V1 = {
    composer: '#prompt-textarea, textarea[data-id="root"]',
    submitBtn: 'button[data-testid="send-button"], button[aria-label="Send prompt"]',
    spinner: '[data-testid="stop-button"], .result-streaming',
    lastResponse: '[data-message-author-role="assistant"]:last-of-type',
  };

  function identify(url) {
    return url.includes('chatgpt.com') || url.includes('openai.com/codex');
  }

  function getComposer() {
    return document.querySelector(CODEX_V1.composer);
  }

  function submit(text) {
    const el = getComposer();
    if (!el) throw new Error('CODEX_V1: composer not found');
    el.focus();
    document.execCommand('insertText', false, text);
    setTimeout(() => {
      const btn = document.querySelector(CODEX_V1.submitBtn);
      if (btn) btn.click();
    }, 80);
  }

  function isGenerating() {
    return !!document.querySelector(CODEX_V1.spinner);
  }

  function getLastResponse() {
    const el = document.querySelector(CODEX_V1.lastResponse);
    return el ? el.innerText.trim() : '';
  }

  window.BrigadeAdapters = window.BrigadeAdapters || {};
  window.BrigadeAdapters.codex = {
    identify,
    getComposer,
    submit,
    isGenerating,
    getLastResponse,
  };
})();
