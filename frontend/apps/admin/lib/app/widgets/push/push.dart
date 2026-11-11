/// Ponte com as notificações do navegador (Web Push), implementada em web/push-cliente.js.
/// Fora do navegador (APK), as notificações push não estão disponíveis nesta versão.
library;

export 'push_padrao.dart' if (dart.library.js_interop) 'push_web.dart';
