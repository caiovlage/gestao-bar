/// Abre um endereço externo (ex.: WhatsApp) em nova aba.
/// Web: abre no navegador. Outras plataformas: devolve false (quem chama oferece copiar o link).
library;

export 'abrir_link_padrao.dart' if (dart.library.js_interop) 'abrir_link_web.dart';
