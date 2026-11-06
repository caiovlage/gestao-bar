/// Editor de texto com formatação (negrito, listas, títulos).
///
/// - Web: edição visual no próprio navegador; colar de um site mantém a formatação.
/// - Android: edição em texto simples (a formatação é editada pelo navegador).
///
/// O conteúdo é HTML; o servidor limpa o que vier colado (remove cores, fontes, scripts).
library;

export 'editor_rico_padrao.dart' if (dart.library.js_interop) 'editor_rico_web.dart';
