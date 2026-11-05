import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

/// Miniatura do produto, com ícone padrão quando não há imagem.
class ProdutoImagem extends StatelessWidget {
  const ProdutoImagem({super.key, this.url, this.bytes, this.tamanho = 48});

  final String? url;

  /// Imagem local ainda não enviada (pré-visualização no formulário).
  final Uint8List? bytes;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: AppCores.fundo,
      child: Icon(Icons.image_outlined, color: Colors.grey.shade400, size: tamanho * 0.45),
    );
    Widget conteudo;
    if (bytes != null) {
      conteudo = Image.memory(bytes!, fit: BoxFit.cover);
    } else if (url != null) {
      conteudo = Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder);
    } else {
      conteudo = placeholder;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(tamanho * 0.2),
      child: SizedBox(width: tamanho, height: tamanho, child: conteudo),
    );
  }
}
