import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Editor visual para o navegador.
///
/// Usa um iframe com o corpo editável (contenteditable): colar, digitar e atalhos
/// (Ctrl+B, Ctrl+I, Ctrl+V) são tratados pelo próprio navegador, isolados do Flutter.
/// Ao colar de um site, negrito, listas e títulos são mantidos.
class EditorRico extends StatefulWidget {
  const EditorRico({super.key, this.htmlInicial, required this.aoAlterar, this.altura = 380});

  final String? htmlInicial;
  final ValueChanged<String> aoAlterar;
  final double altura;

  @override
  State<EditorRico> createState() => _EditorRicoState();
}

class _EditorRicoState extends State<EditorRico> {
  web.HTMLIFrameElement? _iframe;

  static const _estilo = '''
    html, body { margin: 0; }
    body { padding: 14px 16px; font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
           font-size: 16px; line-height: 1.55; color: #1f2328; min-height: 100%; box-sizing: border-box;
           outline: none; word-wrap: break-word; }
    body:empty::before { content: attr(data-placeholder); color: #9ca3af; }
    p { margin: 0 0 .6em; }
    h1, h2, h3, h4 { margin: .8em 0 .4em; line-height: 1.25; }
    ul, ol { margin: 0 0 .6em; padding-left: 1.6em; }
  ''';

  JSObject? get _documento => _iframe?.getProperty<JSObject?>('contentDocument'.toJS);

  JSObject? get _corpo => _documento?.getProperty<JSObject?>('body'.toJS);

  void _criado(Object elemento) {
    final iframe = elemento as web.HTMLIFrameElement;
    _iframe = iframe;
    iframe.style.setProperty('border', 'none');
    iframe.style.setProperty('width', '100%');
    iframe.style.setProperty('height', '100%');
    iframe.style.setProperty('background', 'white');
    iframe.addEventListener('load', ((web.Event _) => _configurar()).toJS);
    final conteudo = widget.htmlInicial ?? '';
    final pagina = '<!doctype html><html><head><meta charset="utf-8"><style>$_estilo</style></head>'
        '<body contenteditable="true" spellcheck="true" '
        'data-placeholder="Digite ou cole aqui o modo de preparo...">$conteudo</body></html>';
    iframe.setProperty('srcdoc'.toJS, pagina.toJS);
  }

  void _configurar() {
    final documento = _documento;
    if (documento == null) return;
    // Parágrafos (<p>) a cada Enter, em vez de <div>.
    documento.callMethod('execCommand'.toJS, 'defaultParagraphSeparator'.toJS, false.toJS, 'p'.toJS);
    documento.callMethod('addEventListener'.toJS, 'input'.toJS, ((web.Event _) => _emitir()).toJS);
  }

  void _emitir() {
    final corpo = _corpo;
    if (corpo == null) return;
    widget.aoAlterar(corpo.getProperty<JSString>('innerHTML'.toJS).toDart);
  }

  /// Executa um comando de formatação na seleção atual do editor.
  void _comando(String nome, [String valor = '']) {
    final documento = _documento;
    if (documento == null) return;
    _iframe?.getProperty<JSObject?>('contentWindow'.toJS)?.callMethod('focus'.toJS);
    documento.callMethod('execCommand'.toJS, nome.toJS, false.toJS, valor.toJS);
    _emitir();
  }

  @override
  Widget build(BuildContext context) {
    Widget botao(IconData icone, String dica, VoidCallback acao) =>
        IconButton(icon: Icon(icone), tooltip: dica, onPressed: acao, visualDensity: VisualDensity.compact);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              botao(Icons.format_bold, 'Negrito (Ctrl+B)', () => _comando('bold')),
              botao(Icons.format_italic, 'Itálico (Ctrl+I)', () => _comando('italic')),
              botao(Icons.format_underlined, 'Sublinhado (Ctrl+U)', () => _comando('underline')),
              const SizedBox(height: 24, child: VerticalDivider()),
              botao(Icons.title, 'Título', () => _comando('formatBlock', 'h3')),
              botao(Icons.notes, 'Texto normal', () => _comando('formatBlock', 'p')),
              const SizedBox(height: 24, child: VerticalDivider()),
              botao(Icons.format_list_bulleted, 'Lista', () => _comando('insertUnorderedList')),
              botao(Icons.format_list_numbered, 'Lista numerada (passos)', () => _comando('insertOrderedList')),
              const SizedBox(height: 24, child: VerticalDivider()),
              botao(Icons.format_clear, 'Limpar formatação da seleção', () => _comando('removeFormat')),
              botao(Icons.undo, 'Desfazer (Ctrl+Z)', () => _comando('undo')),
              botao(Icons.redo, 'Refazer (Ctrl+Y)', () => _comando('redo')),
            ],
          ),
        ),
        Container(
          height: widget.altura,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: Colors.grey.shade300),
              right: BorderSide(color: Colors.grey.shade300),
              bottom: BorderSide(color: Colors.grey.shade300),
            ),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
          ),
          clipBehavior: Clip.antiAlias,
          child: HtmlElementView.fromTagName(tagName: 'iframe', onElementCreated: _criado),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Dica: copie o modo de preparo de um site e cole aqui (Ctrl+V); negrito, listas e títulos são mantidos. '
            'Cores, fontes, imagens e links são removidos ao salvar.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }
}
