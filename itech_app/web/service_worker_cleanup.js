'use strict';

// Migration worker for devices that installed an older Flutter app-shell PWA.
// It immediately replaces the old worker, clears its control of the page, and
// reloads open app windows so they receive the current deployment.
self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      await self.registration.unregister();
      const clients = await self.clients.matchAll({type: 'window'});
      await Promise.all(
        clients.map((client) => client.url ? client.navigate(client.url) : null),
      );
    })(),
  );
});
