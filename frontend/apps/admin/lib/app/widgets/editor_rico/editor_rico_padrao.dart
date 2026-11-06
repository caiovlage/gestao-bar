import 'package:flutter/material.dart';

/// Editor para plataformas fora do navegador (APK Android): texto simples.
/// O texto é convertido em parágrafos HTML; a formatação visual é editada pelo navegador.
class EditorRico extends StatefulWidget {
  const EditorRico({super.key, this.htmlInicial, required this.aoAlterar, this.altura = 380});

  final String? htmlInicial;
  final ValueChanged<String> aoAlterar;
  final double altura;

  @override
  State<EditorRico> createState() => _EditorRicoState();
}

class _EditorRicoState extends State<EditorRico> {
  late final _controller = TextEditingController(text: _paraTexto(widget.htmlInicial ?? ''));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String _paraTexto(String html) => html
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'</(p|h[1-6]|li|blockquote)>|<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  static String _paraHtml(String texto) => texto
      .split('\n')
      .map((linha) => linha.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;'))
      .map((linha) => '<p>${linha.isEmpty ? '<br>' : linha}</p>')
      .join();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: widget.altura,
          child: TextField(
            controller: _controller,
            expands: true,
            maxLines: null,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(hintText: 'Modo de preparo...'),
            onChanged: (t) => widget.aoAlterar(_paraHtml(t)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'No aplicativo o texto é editado sem formatação. Para colar com negrito e listas, edite pelo navegador.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }
}
