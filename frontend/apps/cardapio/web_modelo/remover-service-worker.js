// Remove o service worker de cache do Flutter instalado por versões anteriores do cardápio.
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then(function (registros) {
    registros.forEach(function (r) {
      if (r.active && /flutter_service_worker\.js/.test(r.active.scriptURL)) r.unregister();
    });
  }).catch(function () {});
}
