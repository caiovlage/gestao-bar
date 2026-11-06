import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Largura abaixo da qual a tela é tratada como celular.
const larguraCelular = 600.0;

/// true em telas de celular (largura menor que [larguraCelular]).
bool ehCelular(BuildContext context) => MediaQuery.sizeOf(context).width < larguraCelular;

/// Grade que preenche a linha por igual: quantas colunas de ~[larguraItem] couberem,
/// nunca menos que [colunasMinimas] (no celular, 2 cartões lado a lado).
class GradeResponsiva extends StatelessWidget {
  const GradeResponsiva({
    super.key,
    required this.children,
    this.larguraItem = 220,
    this.colunasMinimas = 2,
    this.espaco = 12,
  });

  final List<Widget> children;
  final double larguraItem;
  final int colunasMinimas;
  final double espaco;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final largura = c.maxWidth;
      final esp = largura < larguraCelular ? 10.0 : espaco;
      final colunas = math.max(colunasMinimas, ((largura + esp) / (larguraItem + esp)).floor());
      final item = ((largura - esp * (colunas - 1)) / colunas).floorToDouble();
      return Wrap(
        spacing: esp,
        runSpacing: esp,
        children: [for (final filho in children) SizedBox(width: item, child: filho)],
      );
    });
  }
}
