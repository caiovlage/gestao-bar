import 'package:flutter/material.dart';

import 'grade_responsiva.dart';

/// Título da página com subtítulo e ações à direita (quebra em telas estreitas).
class CabecalhoPagina extends StatelessWidget {
  const CabecalhoPagina({super.key, required this.titulo, this.subtitulo, this.acoes = const []});

  final String titulo;
  final String? subtitulo;
  final List<Widget> acoes;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final celular = ehCelular(context);
    final titulos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(titulo,
            style: (celular ? tema.textTheme.titleLarge : tema.textTheme.headlineSmall)
                ?.copyWith(fontWeight: FontWeight.w700)),
        if (subtitulo != null)
          Text(subtitulo!,
              style: (celular ? tema.textTheme.bodySmall : tema.textTheme.bodyMedium)
                  ?.copyWith(color: Colors.grey.shade600)),
      ],
    );
    if (celular) {
      // Botões menores e em uma linha rolável, para não ocupar meia tela
      final compacto = ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, 38)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14)),
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStatePropertyAll(tema.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          titulos,
          if (acoes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Theme(
              data: tema.copyWith(
                filledButtonTheme:
                    FilledButtonThemeData(style: compacto.merge(tema.filledButtonTheme.style)),
                outlinedButtonTheme:
                    OutlinedButtonThemeData(style: compacto.merge(tema.outlinedButtonTheme.style)),
                textButtonTheme: TextButtonThemeData(style: compacto.merge(tema.textButtonTheme.style)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final (i, a) in acoes.indexed) ...[if (i > 0) const SizedBox(width: 8), a],
                ]),
              ),
            ),
          ],
        ]),
      );
    }
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
