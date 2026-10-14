(() => {
  'use strict';

  // Check for releases while an iOS home-screen PWA is running. Never delete
  // IndexedDB, localStorage, CacheStorage, or Web Push registrations.
  const script = document.currentScript;
  if (!script) return;
  const currentVersion = new URL(script.src, document.baseURI).searchParams.get('v');
  if (!/^[a-f0-9]{40}$/.test(currentVersion ?? '')) return;

  const latestUrl = new URL('folego_version.json', document.baseURI);
  let lastChecked = 0;
  let inFlight = false;
  let dismissedVersion = '';
  const intervalMs = 3 * 60 * 1000;

  function showNotice(version) {
    if (document.getElementById('folego-new-version-notice') ||
        dismissedVersion === version) return;

    const css = document.createElement('style');
    css.textContent = `
      #folego-new-version-notice {
        position: fixed;
        z-index: 2147483646;
        inset-inline: 12px;
        top: calc(env(safe-area-inset-top, 0px) + 12px);
        max-width: 480px;
        margin-inline: auto;
        padding: 16px;
        color: #17151f;
        background: #f8f4ff;
        border: 1px solid #d6c5ff;
        border-radius: 18px;
        box-shadow: 0 12px 36px rgba(18, 12, 36, .22);
        box-sizing: border-box;
        font: 14px/1.45 system-ui, -apple-system, sans-serif;
      }
      #folego-new-version-notice .folego-update-title {
        font-size: 15px;
        font-weight: 750;
        margin-bottom: 4px;
      }
      #folego-new-version-notice .folego-update-actions {
        display: flex;
        justify-content: flex-end;
        gap: 8px;
        margin-top: 12px;
      }
      #folego-new-version-notice button {
        min-height: 40px;
        padding: 8px 14px;
        font: inherit;
        font-weight: 650;
        border-radius: 12px;
        cursor: pointer;
      }
      #folego-update-later {
        border: 1px solid #c5bbd6;
        background: transparent;
        color: inherit;
      }
      #folego-update-now {
        border: 1px solid #5731b5;
        background: #5731b5;
        color: white;
      }
      @media (prefers-color-scheme: dark) {
        #folego-new-version-notice {
          background: #24212c;
          border-color: #534966;
          color: #f9f6ff;
        }
        #folego-update-later { border-color: #786b89; }
      }
    `;
    document.head.appendChild(css);

    const notice = document.createElement('aside');
    notice.id = 'folego-new-version-notice';
    notice.setAttribute('role', 'status');
    notice.setAttribute('aria-live', 'polite');

    const title = document.createElement('div');
    title.className = 'folego-update-title';
    title.textContent = '✨ nova versão disponível';

    const description = document.createElement('div');
    description.textContent =
      'Tem novidade no Fôlego! Salve alterações em andamento antes de atualizar. ' +
      'Seus dados continuam salvos.';

    const actions = document.createElement('div');
    actions.className = 'folego-update-actions';

    const later = document.createElement('button');
    later.type = 'button';
    later.id = 'folego-update-later';
    later.textContent = 'depois';
    later.addEventListener('click', () => {
      dismissedVersion = version;
      notice.remove();
      css.remove();
    });

    const update = document.createElement('button');
    update.type = 'button';
    update.id = 'folego-update-now';
    update.textContent = 'atualizar agora';
    update.addEventListener('click', () => {
      // The user decides when to reload, so unsaved edits are not interrupted.
      window.location.reload();
    });

    actions.append(later, update);
    notice.append(title, description, actions);
    document.body.appendChild(notice);
  }

  async function checkForUpdate() {
    if (inFlight || document.visibilityState === 'hidden') return;
    const now = Date.now();
    if (now - lastChecked < 60 * 1000) return;
    lastChecked = now;
    inFlight = true;
    const abort = new AbortController();
    const deadline = setTimeout(() => abort.abort(), 8000);
    try {
      const url = new URL(latestUrl);
      url.searchParams.set('t', String(now));
      const response = await fetch(url.href, {
        method: 'GET',
        cache: 'no-store',
        credentials: 'same-origin',
        signal: abort.signal,
      });
      if (!response.ok ||
          !(response.headers.get('content-type') ?? '').includes('application/json')) {
        return;
      }
      const payload = await response.json();
      const version = payload && typeof payload.version === 'string'
        ? payload.version : '';
      if (/^[a-f0-9]{40}$/.test(version) && version !== currentVersion) {
        showNotice(version);
      }
    } catch (_) {
      // Offline PWA sessions must keep working without intrusive error banners.
    } finally {
      clearTimeout(deadline);
      inFlight = false;
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', checkForUpdate, { once: true });
  } else {
    checkForUpdate();
  }
  window.addEventListener('pageshow', checkForUpdate);
  window.addEventListener('focus', checkForUpdate);
  window.addEventListener('online', checkForUpdate);
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') checkForUpdate();
  });
  window.setInterval(checkForUpdate, intervalMs);
})();
