/// Sem navegador: não há Web Push.
Future<String> estadoPush() async => 'nao-suportado';

Future<String> ativarPush(String chavePublica) async => '{"erro":"nao-suportado"}';

Future<String> desativarPush() async => '';

Future<String> endpointPush() async => '';

String nomeAparelho() => 'Aparelho';
