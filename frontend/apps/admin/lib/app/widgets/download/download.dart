/// Salva um arquivo recebido da API (PDF, Excel).
/// Web: dispara o download no navegador. Outras plataformas: não suportado nesta versão.
library;

export 'download_padrao.dart' if (dart.library.js_interop) 'download_web.dart';
