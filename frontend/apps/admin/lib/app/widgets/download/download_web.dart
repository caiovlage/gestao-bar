import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Dispara o download do arquivo no navegador. Retorna true se iniciou.
Future<bool> baixarArquivo(List<int> bytes, String nome, String tipo) async {
  final dados = Uint8List.fromList(bytes);
  final blob = web.Blob(<JSAny>[dados.toJS].toJS, web.BlobPropertyBag(type: tipo));
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = nome;
  web.document.body?.appendChild(link);
  link.click();
  link.remove();
  web.URL.revokeObjectURL(url);
  return true;
}
