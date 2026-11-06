import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Largura abaixo da qual a tela é tratada como celular. Todos os ajustes de layout
/// "mobile" valem só abaixo dela; em tablet e computador o layout não muda.
const larguraCelular = 600.0;

/// true em telas de celular (largura menor que [larguraCelular]).
bool ehCelular(BuildContext context) => MediaQuery.sizeOf(context).width < larguraCelular;

/// Cartões em grade. No computador: largura fixa [larguraItem], como sempre foi.
/// No celular: preenchem a linha por igual, no mínimo [colunasMinimas] lado a lado.
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
    if (!ehCelular(context)) {
      return Wrap(
        spacing: espaco,
        runSpacing: espaco,
        children: [for (final filho in children) SizedBox(width: larguraItem, child: filho)],
      );
    }
    return LayoutBuilder(builder: (context, c) {
      const esp = 10.0;
      final largura = c.maxWidth;
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

/// Campo de filtro/formulário com largura fixa no computador. No celular ocupa a linha
/// inteira ([larguraCelularInteira] ou largura ≥ 260) ou metade dela (2 campos por linha).
/// Use dentro de um [Wrap].
class LarguraCampo extends StatelessWidget {
  const LarguraCampo({super.key, required this.largura, required this.child, this.larguraCelularInteira});

  final double largura;
  final Widget child;

  /// Força linha inteira (true) ou meia linha (false) no celular; nulo = decide pela largura.
  final bool? larguraCelularInteira;

  @override
  Widget build(BuildContext context) {
    if (!ehCelular(context)) return SizedBox(width: largura, child: child);
    return LayoutBuilder(builder: (context, c) {
      final inteira = larguraCelularInteira ?? largura >= 260;
      final w = c.maxWidth.isFinite ? c.maxWidth : MediaQuery.sizeOf(context).width - 24;
      return SizedBox(width: inteira ? w : ((w - 16) / 2).floorToDouble(), child: child);
    });
  }
}

/// No celular, deixa rolar para o lado o que não cabe (ex.: botões segmentados).
/// No computador, devolve o próprio filho.
class RolavelNoCelular extends StatelessWidget {
  const RolavelNoCelular({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!ehCelular(context)) return child;
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: child);
  }
}
