// Anti Gravity adapter — selectors versioned as AGY_V1
(function () {
  const AGY_V1 = {
    composer: 'textarea[data-testid="chat-input"], .chat-composer textarea, textarea',
    submitBtn: 'button[data-testid="send-btn"], button[aria-label="Send"], button.send-button',
    spinner: '.generating-indicator, [data-testid="loading"], .spinner',
    lastResponse: '.assistant-message:last-of-type, [data-role="assistant"]:last-of-type, .message-bubble.assistant:last-of-type',
  };

  function identify(url) {
    return url.includes('antigravity') || url.includes('agy.dev') || url.includes('google.com');
  }

  function getComposer() {
    return document.querySelector(AGY_V1.composer);
  }

  function submit(text) {
    const el = getComposer();
    if (!el) throw new Error('AGY_V1: composer not found');
    el.focus();
    document.execCommand('insertText', false, text);
    setTimeout(() => {
      const btn = document.querySelector(AGY_V1.submitBtn);
      if (btn) btn.click();
    }, 80);
  }

  function isGenerating() {
    return !!document.querySelector(AGY_V1.spinner);
  }

  function getLastResponse() {
    const el = document.querySelector(AGY_V1.lastResponse);
    return el ? el.innerText.trim() : '';
  }

  window.BrigadeAdapters = window.BrigadeAdapters || {};
  window.BrigadeAdapters.antigravity = {
    identify,
    getComposer,
    submit,
    isGenerating,
    getLastResponse,
  };
})();
