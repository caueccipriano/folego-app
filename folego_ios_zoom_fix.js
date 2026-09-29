(() => {
  const isIOS =
    /iPad|iPhone|iPod/.test(navigator.userAgent) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);

  if (!isIOS) return;

  const patchedRoots = new WeakSet();
  const styleText = 'input, textarea { font-size: 16px !important; }';

  function ensureEditableFontSize(element) {
    if (
      element instanceof HTMLInputElement ||
      element instanceof HTMLTextAreaElement
    ) {
      element.style.setProperty('font-size', '16px', 'important');
    }
  }

  function scan(root) {
    if (root instanceof Element) {
      ensureEditableFontSize(root);
      if (root.shadowRoot) patchRoot(root.shadowRoot);
    }

    if (!root.querySelectorAll) return;

    root.querySelectorAll('input, textarea').forEach(ensureEditableFontSize);
    root.querySelectorAll('*').forEach((element) => {
      if (element.shadowRoot) patchRoot(element.shadowRoot);
    });
  }

  function installStyle(root) {
    const style = document.createElement('style');
    style.dataset.folegoIosInputZoomFix = 'true';
    style.textContent = styleText;

    if (root instanceof Document) {
      root.head.appendChild(style);
    } else {
      root.appendChild(style);
    }
  }

  function patchRoot(root) {
    if (patchedRoots.has(root)) return;
    patchedRoots.add(root);

    installStyle(root);
    scan(root);

    const observer = new MutationObserver((records) => {
      for (const record of records) {
        for (const node of record.addedNodes) {
          if (
            node instanceof Element ||
            node instanceof ShadowRoot ||
            node instanceof DocumentFragment
          ) {
            scan(node);
          }
        }
      }
    });

    observer.observe(root, { subtree: true, childList: true });
  }

  patchRoot(document);

  // Flutter attaches some shadow roots after its bootstrap starts. A short
  // bounded scan makes sure those roots receive the same 16px floor.
  let attempts = 0;
  const bootstrapScan = window.setInterval(() => {
    scan(document);
    attempts += 1;
    if (attempts >= 40) window.clearInterval(bootstrapScan);
  }, 250);

  document.addEventListener(
    'focusin',
    (event) => {
      for (const node of event.composedPath()) {
        if (node instanceof HTMLInputElement || node instanceof HTMLTextAreaElement) {
          ensureEditableFontSize(node);
        }
      }
    },
    true,
  );
})();
