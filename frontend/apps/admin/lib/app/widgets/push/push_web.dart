import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Objeto window.entreNosPush (web/push-cliente.js); nulo se o script não carregou.
JSObject? get _api =>
    globalContext.has('entreNosPush') ? globalContext.getProperty<JSObject>('entreNosPush'.toJS) : null;

Future<String> _chamar(String metodo, [String? argumento]) async {
  final api = _api;
  if (api == null) return '';
  final promessa = argumento == null
      ? api.callMethod<JSPromise<JSString>>(metodo.toJS)
      : api.callMethod<JSPromise<JSString>>(metodo.toJS, argumento.toJS);
  return (await promessa.toDart).toDart;
}

/// inseguro | ios-instalar | nao-suportado | bloqueado | inativo | ativo
Future<String> estadoPush() async => _api == null ? 'nao-suportado' : _chamar('estado');

/// Pede permissão e inscreve; devolve o JSON da inscrição ou {"erro": ...}.
Future<String> ativarPush(String chavePublica) => _chamar('ativar', chavePublica);

/// Cancela a inscrição deste aparelho; devolve o endpoint cancelado.
Future<String> desativarPush() => _chamar('desativar');

Future<String> endpointPush() => _chamar('endpoint');

String nomeAparelho() {
  final api = _api;
  if (api == null) return 'Navegador';
  return api.callMethod<JSString>('nomeAparelho'.toJS).toDart;
}

/// instalado | sim | ios | nao
Future<String> instalacaoApp() async => _api == null ? 'nao' : _chamar('instalacao');

/// accepted | dismissed | indisponivel
Future<String> instalarApp() => _chamar('instalar');
