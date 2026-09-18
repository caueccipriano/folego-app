const CACHE_PREFIX = 'folego-shell-';
const CACHE_VERSION = '__FOLEGO_CACHE_VERSION__';
const CACHE_NAME = `${CACHE_PREFIX}${CACHE_VERSION}`;
const OFFLINE_FALLBACK_URL = new URL('index.html', self.registration.scope).href;

const APP_SHELL_URLS = [
  'index.html',
  'manifest.json',
  'flutter_bootstrap.js',
  'flutter.js',
  'main.dart.js',
  'folego_ios_zoom_fix.js',
  'folego_push_bridge.js',
  'favicon.png',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
  'icons/Icon-maskable-192.png',
  'icons/Icon-maskable-512.png',
].map((path) => new URL(path, self.registration.scope).href);

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    await cache.addAll(APP_SHELL_URLS);
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const cacheNames = await caches.keys();
    await Promise.all(
      cacheNames
        .filter(
          (name) => name.startsWith(CACHE_PREFIX) && name !== CACHE_NAME,
        )
        .map((name) => caches.delete(name)),
    );
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  const scope = new URL(self.registration.scope);

  // Never cache Supabase/API traffic or third-party resources here. Financial
  // data must keep its own consistency rules; this worker only caches the app
  // shell and same-origin static Flutter assets.
  if (url.origin !== scope.origin || !url.pathname.startsWith(scope.pathname)) {
    return;
  }

  if (request.mode === 'navigate') {
    event.respondWith((async () => {
      try {
        const response = await fetch(request);
        if (response.ok) {
          const cache = await caches.open(CACHE_NAME);
          await cache.put(OFFLINE_FALLBACK_URL, response.clone());
        }
        return response;
      } catch (_) {
        const cached = await caches.match(OFFLINE_FALLBACK_URL);
        if (cached) return cached;
        throw _;
      }
    })());
    return;
  }

  event.respondWith((async () => {
    const cached = await caches.match(request);

    const networkFetch = fetch(request)
      .then(async (response) => {
        if (response.ok) {
          const cache = await caches.open(CACHE_NAME);
          await cache.put(request, response.clone());
        }
        return response;
      })
      .catch(() => null);

    if (cached) {
      event.waitUntil(networkFetch);
      return cached;
    }

    const networkResponse = await networkFetch;
    if (networkResponse) return networkResponse;

    return Response.error();
  })());
});

self.addEventListener('message', (event) => {
  if (event.data?.type === 'SKIP_WAITING') self.skipWaiting();
});

self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (_) {
    data = { body: event.data?.text() ?? '' };
  }

  const title = data.title || 'Fôlego';
  const icon = new URL(data.icon || 'icons/Icon-192.png', self.registration.scope).href;
  const badge = new URL(data.badge || 'icons/Icon-192.png', self.registration.scope).href;

  event.waitUntil(
    self.registration.showNotification(title, {
      body: data.body || '',
      tag: data.tag || undefined,
      renotify: false,
      icon,
      badge,
      data: {
        route: data.route || '/',
      },
    }),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const route = event.notification.data?.route || '/';
  const target = new URL(self.registration.scope);
  target.searchParams.set('push_route', route);

  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({
      type: 'window',
      includeUncontrolled: true,
    });

    for (const client of windows) {
      if (!client.url.startsWith(self.registration.scope)) continue;

      const navigated = await client.navigate(target.href);
      if (navigated) {
        await navigated.focus();
      } else {
        await client.focus();
      }
      return;
    }

    await self.clients.openWindow(target.href);
  })());
});
