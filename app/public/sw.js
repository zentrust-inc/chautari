// चौतारी (Chautari) — keeps the whole app on the phone so it opens without internet.
// At build time vite.config.ts fills in PRECACHE (every file of this build) and the cache name,
// so a new build installs as a new version and the old one is removed.
// Data from the server is never cached here: the app keeps its last public figures itself and says when it is offline.
const CACHE = 'chautari-__BUILD_ID__';
const PRECACHE = __PRECACHE__;
self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(PRECACHE)));
  self.skipWaiting();
});
self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((ks) => Promise.all(ks.filter((k) => k !== CACHE).map((k) => caches.delete(k)))));
  self.clients.claim();
});
self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);
  if (e.request.method !== 'GET' || url.origin !== location.origin) return;   // API calls go straight to the network
  // Opening the app (any page address) gets the saved index.html when offline.
  const req = e.request.mode === 'navigate' ? './index.html' : e.request;
  e.respondWith(
    caches.open(CACHE).then((c) => c.match(req, { ignoreSearch: true }).then((hit) => {
      const net = fetch(e.request).then((res) => {
        if (res.ok && e.request.mode !== 'navigate') c.put(e.request, res.clone());
        return res;
      });
      return hit || net;
    })),
  );
});
