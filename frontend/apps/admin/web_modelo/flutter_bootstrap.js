{{flutter_js}}
{{flutter_build_config}}

// Sem o service worker de cache do Flutter (descontinuado): o painel usa o push-sw.js
// para as notificações de novos pedidos e sempre carrega a versão atual do servidor.
_flutter.loader.load();
