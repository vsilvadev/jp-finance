const CACHE_PREFIX = 'japao-gastos-';
const CACHE_NAME = `${CACHE_PREFIX}__BUILD_ID__`;

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const manifestUrl = new URL('precache-manifest.json', self.registration.scope);
    const response = await fetch(manifestUrl, { cache: 'no-store' });
    if (!response.ok) throw new Error('Não foi possível ler o manifesto offline.');

    const assets = await response.json();
    const cache = await caches.open(CACHE_NAME);
    await cache.addAll(assets.map((path) => new URL(path, self.registration.scope)));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names
      .filter((name) => name.startsWith(CACHE_PREFIX) && name !== CACHE_NAME)
      .map((name) => caches.delete(name)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== self.location.origin) return;

  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    const cached = await cache.match(request, { ignoreSearch: true });
    if (cached) return cached;

    try {
      return await fetch(request);
    } catch (error) {
      if (request.mode === 'navigate') {
        const appShell = await cache.match(new URL('index.html', self.registration.scope));
        if (appShell) return appShell;
      }
      throw error;
    }
  })());
});
