import 'package:web/web.dart' as web;

/// Abre o endereço em uma nova aba (no celular, o WhatsApp abre direto).
Future<bool> abrirLink(String url) async {
  web.window.open(url, '_blank');
  return true;
}
