const tokenInput = document.getElementById('token');
const status = document.getElementById('status');

chrome.storage.local.get('bridgeToken').then((stored) => {
  tokenInput.value = typeof stored.bridgeToken === 'string' ? stored.bridgeToken : '';
});

document.getElementById('save').addEventListener('click', async () => {
  await chrome.storage.local.set({bridgeToken: tokenInput.value.trim()});
  status.textContent = 'Saved. Reload connected tabs to pair them.';
  setTimeout(() => { status.textContent = ''; }, 3000);
});
