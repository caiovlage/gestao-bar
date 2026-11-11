// Service worker do painel: recebe as notificações push de novos pedidos (Web Push)
// e abre a tela de Pedidos ao tocar. Não guarda arquivos em cache: o painel sempre
// vem atualizado do servidor.

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (evento) => evento.waitUntil(self.clients.claim()));

self.addEventListener('push', (evento) => {
  let dados = {};
  try {
    dados = evento.data ? evento.data.json() : {};
  } catch (_) {
    dados = { corpo: evento.data ? evento.data.text() : '' };
  }
  const titulo = dados.titulo || 'Entre Nós';
  evento.waitUntil(
    self.registration.showNotification(titulo, {
      body: dados.corpo || '',
      icon: 'icons/Icon-192.png',
      badge: 'icons/badge-96.png',
      tag: dados.tag || undefined,
      renotify: Boolean(dados.tag),
      requireInteraction: true, // no computador, fica na tela até alguém ver
      vibrate: [200, 100, 200, 100, 300],
      data: { url: dados.url || '/admin/pedidos' },
    }),
  );
});

self.addEventListener('notificationclick', (evento) => {
  evento.notification.close();
  const destino = new URL((evento.notification.data && evento.notification.data.url) || '/admin/pedidos',
    self.location.origin).href;
  evento.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((janelas) => {
      for (const janela of janelas) {
        if (janela.url.includes('/admin/')) {
          return janela.focus().then((j) => (j && 'navigate' in j ? j.navigate(destino) : j));
        }
      }
      return self.clients.openWindow(destino);
    }),
  );
});
