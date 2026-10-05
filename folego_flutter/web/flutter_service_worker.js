const CACHE_PREFIXES = ['flutter-app-cache', 'folego', 'workbox'];

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names.filter((name) => CACHE_PREFIXES.some((prefix) => name.includes(prefix))).map((name) => caches.delete(name)));
    const clients = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const client of clients) {
      client.postMessage({ type: 'FOLEGO_RETIRED', target: 'https://caueccipriano.github.io/mylife-caue-app/#/dinheiro' });
    }
    await self.registration.unregister();
  })());
});
