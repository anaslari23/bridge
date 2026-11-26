const connectButton = document.querySelector('#connect');
const disconnectButton = document.querySelector('#disconnect');
const tabName = document.querySelector('#tab-name');
const status = document.querySelector('#status');

async function activeTab() {
  const [tab] = await chrome.tabs.query({active: true, currentWindow: true});
  return tab;
}

async function refresh() {
  const tab = await activeTab();
  if (!tab?.id) {
    status.textContent = 'No active tab is available.';
    return;
  }
  tabName.textContent = tab.title || tab.url || 'Current tab';
  const {connectedTabIds = []} = await chrome.storage.local.get('connectedTabIds');
  const connected = connectedTabIds.includes(tab.id);
  connectButton.hidden = connected;
  disconnectButton.hidden = !connected;
}

connectButton.addEventListener('click', async () => {
  const tab = await activeTab();
  if (!tab?.id || !tab.url?.startsWith('https://')) {
    status.textContent = 'Connect a secure web page.';
    return;
  }
  const result = await chrome.runtime.sendMessage({type: 'CONNECT_TAB', tabId: tab.id});
  status.textContent = result?.ok ? 'Tab connected.' : result?.error || 'Could not connect this tab.';
  await refresh();
});

disconnectButton.addEventListener('click', async () => {
  const tab = await activeTab();
  if (!tab?.id) return;
  await chrome.runtime.sendMessage({type: 'DISCONNECT_TAB', tabId: tab.id});
  status.textContent = 'Tab disconnected.';
  await refresh();
});

refresh().catch(() => { status.textContent = 'Could not read the active tab.'; });
