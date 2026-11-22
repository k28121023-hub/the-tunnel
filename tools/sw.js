/* The Tunnel service worker.
 * Hashed engine-* / asset-* files are cache-first (content-addressed, safe).
 * HTML and other unhashed files are network-first so a new deploy is picked up.
 * Kill switch: open the game with ?nosw=1 (or ?sw=off) to unregister and clear caches.
 * __CACHE_VERSION__ is replaced at export time.
 *
 * Scope isolation: a root worker registered at /the-tunnel/ would also see
 * fetches under /the-tunnel/travel/. Only handle files in this worker's own
 * directory, and only delete caches tagged with this scope prefix.
 */
const SCOPE_PATH = new URL(self.registration.scope).pathname;
const CACHE_PREFIX = 'tunnel-app:' + SCOPE_PATH;
const CACHE_VERSION = CACHE_PREFIX + '__CACHE_VERSION__';
const HASHED = /\/(?:engine-|asset-)[a-f0-9][^/]*$/i;
const NEVER_CACHE = /\/(?:sw\.js)(?:$|\?)/i;

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(
      keys
        .filter((key) => key.startsWith(CACHE_PREFIX) && key !== CACHE_VERSION)
        .map((key) => caches.delete(key))
    );
    await self.clients.claim();
  })());
});

function isOwnAsset(url) {
  if (url.origin !== self.location.origin) return false;
  // /the-tunnel (no trailing slash) belongs to scope /the-tunnel/.
  if (url.pathname + '/' === SCOPE_PATH) return true;
  if (!url.pathname.startsWith(SCOPE_PATH)) return false;
  const rest = url.pathname.slice(SCOPE_PATH.length);
  // Files in this directory only — not a child app such as /travel/.
  return rest === '' || !rest.includes('/');
}

function isHashedAsset(url) {
  return HASHED.test(url.pathname);
}

function isDocument(request, url) {
  if (request.destination === 'document') return true;
  const path = url.pathname;
  return path.endsWith('/') || path.endsWith('.html') || path + '/' === SCOPE_PATH;
}

async function cacheFirst(request) {
  const cached = await caches.match(request);
  if (cached) return cached;
  const fresh = await fetch(request);
  if (fresh && fresh.ok) {
    const cache = await caches.open(CACHE_VERSION);
    await cache.put(request, fresh.clone());
  }
  return fresh;
}

async function networkFirst(request, cacheKey) {
  const cache = await caches.open(CACHE_VERSION);
  try {
    const fresh = await fetch(request, { cache: 'no-store' });
    if (fresh && fresh.ok) cache.put(cacheKey, fresh.clone());
    return fresh;
  } catch (err) {
    const cached = await cache.match(cacheKey) || await caches.match(request);
    if (cached) return cached;
    throw err;
  }
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  let url;
  try { url = new URL(request.url); } catch { return; }
  if (!isOwnAsset(url)) return;
  if (NEVER_CACHE.test(url.pathname)) return;

  if (isHashedAsset(url)) {
    event.respondWith(cacheFirst(request));
    return;
  }
  if (isDocument(request, url) || /\/loading-status\.js$/.test(url.pathname)) {
    // Ignore ?v= when storing HTML so a later visit can fall back offline.
    const key = new Request(url.origin + url.pathname, { method: 'GET' });
    event.respondWith(networkFirst(request, key));
  }
});
