const BUILD_VERSION = '__FOLEGO_CACHE_VERSION__';

// This service worker exists for Web Push only.
// Do not intercept app-shell requests here: cache-first delivery of Flutter's
// main.dart.js can keep an installed iOS PWA on an old build and make visual
// geometry/hit testing look "stuck" after a deploy.
self.__FOLEGO_BUILD_VERSION__ = BUILD_VERSION;

self.addEventListener('install', (event) => {
  event.waitUntil(self.skipWaiting());
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
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
