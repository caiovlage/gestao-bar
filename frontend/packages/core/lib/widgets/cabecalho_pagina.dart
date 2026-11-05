import 'package:flutter/material.dart';

/// Título da página com subtítulo e ações à direita (quebra em telas estreitas).
class CabecalhoPagina extends StatelessWidget {
  const CabecalhoPagina({super.key, required this.titulo, this.subtitulo, this.acoes = const []});

  final String titulo;
  final String? subtitulo;
  final List<Widget> acoes;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 12,
        spacing: 12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(titulo, style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              if (subtitulo != null)
                Text(subtitulo!, style: tema.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600)),
            ],
          ),
          if (acoes.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: acoes),
        ],
      ),
    );
  }
}
