import 'package:core/core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'relatorios.dart';

/// Paleta dos gráficos (âmbar da identidade + cores de apoio legíveis).
const coresGrafico = [
  Color(0xFFF59E0B),
  Color(0xFF1F2328),
  Color(0xFF0EA5E9),
  Color(0xFF10B981),
  Color(0xFF8B5CF6),
  Color(0xFFEF4444),
  Color(0xFF64748B),
];

final _compacto = NumberFormat.compactCurrency(locale: 'pt_BR', symbol: r'R$', decimalDigits: 0);

String moedaCompacta(num v) => _compacto.format(v);

/// Cartão de indicador (KPI) com ícone, valor, detalhe e variação opcional.
class CartaoIndicador extends StatelessWidget {
  const CartaoIndicador({
    super.key,
    required this.titulo,
    required this.valor,
    required this.icone,
    this.detalhe,
    this.variacao,
    this.cor = AppCores.ambarEscuro,
    this.largura,
  });

  final String titulo;
  final String valor;
  final IconData icone;
  final String? detalhe;
  final num? variacao;
  final Color cor;

  /// Largura fixa; nula = ocupa a largura dada pelo pai (ex.: [GradeResponsiva]).
  final double? largura;

  @override
  Widget build(BuildContext context) {
    final v = variacao;
    final c = ehCelular(context);
    return SizedBox(
      width: largura,
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(c ? 12 : 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: EdgeInsets.all(c ? 6 : 8),
                decoration: BoxDecoration(color: cor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(c ? 8 : 10)),
                child: Icon(icone, color: cor, size: c ? 16 : 20),
              ),
              SizedBox(width: c ? 8 : 10),
              Expanded(
                child: Text(titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: c ? 12 : 13, height: 1.2)),
              ),
            ]),
            SizedBox(height: c ? 8 : 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(valor, style: TextStyle(fontSize: c ? 19 : 24, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 4),
            Row(children: [
              if (v != null) ...[
                Icon(v >= 0 ? Icons.trending_up : Icons.trending_down,
                    size: c ? 14 : 16, color: v >= 0 ? AppCores.sucesso : AppCores.perigo),
                const SizedBox(width: 3),
                Text('${v >= 0 ? '+' : ''}${formatarPercentual(v)}',
                    style: TextStyle(
                        fontSize: c ? 11 : 12, fontWeight: FontWeight.w700, color: v >= 0 ? AppCores.sucesso : AppCores.perigo)),
                const SizedBox(width: 6),
              ],
              if (detalhe != null)
                Expanded(
                  child: Text(detalhe!,
                      style: TextStyle(fontSize: c ? 11 : 12, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Card com título para gráficos e tabelas.
class PainelCard extends StatelessWidget {
  const PainelCard({super.key, required this.titulo, this.subtitulo, required this.child, this.altura});

  final String titulo;
  final String? subtitulo;
  final Widget child;
  final double? altura;

  @override
  Widget build(BuildContext context) {
    final celular = ehCelular(context);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(celular ? 14 : 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(titulo, style: TextStyle(fontWeight: FontWeight.w700, fontSize: celular ? 15 : 16)),
          if (subtitulo != null) Text(subtitulo!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const SizedBox(height: 16),
          if (altura != null) SizedBox(height: altura, child: child) else child,
        ]),
      ),
    );
  }
}

FlTitlesData _titulos({required Widget Function(double, TitleMeta) inferior, double intervaloInferior = 1}) => FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 56,
          getTitlesWidget: (v, meta) => Text(moedaCompacta(v), style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: true, reservedSize: 26, interval: intervaloInferior, getTitlesWidget: inferior),
      ),
    );

/// Faturamento e lucro bruto por dia (linhas).
class GraficoVendasDia extends StatelessWidget {
  const GraficoVendasDia({super.key, required this.pontos});

  final List<PontoDia> pontos;

  @override
  Widget build(BuildContext context) {
    if (pontos.isEmpty) return const Center(child: Text('Sem vendas no período'));
    final intervalo = (pontos.length / 7).ceilToDouble().clamp(1, 60).toDouble();
    LineChartBarData linha(List<FlSpot> spots, Color cor, {bool area = false}) => LineChartBarData(
          spots: spots,
          isCurved: true,
          preventCurveOverShooting: true,
          color: cor,
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: area, color: cor.withValues(alpha: 0.15)),
        );
    return LineChart(LineChartData(
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      titlesData: _titulos(
        intervaloInferior: intervalo,
        inferior: (v, meta) {
          final i = v.toInt();
          if (i < 0 || i >= pontos.length) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(DateFormat('dd/MM').format(pontos[i].data), style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          );
        },
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => [
            for (final s in spots)
              LineTooltipItem(
                '${s.barIndex == 0 ? 'Faturamento' : 'Lucro bruto'}\n${formatarMoeda(s.y)}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
              ),
          ],
        ),
      ),
      lineBarsData: [
        linha([for (final (i, p) in pontos.indexed) FlSpot(i.toDouble(), p.faturamento.toDouble())], coresGrafico[0], area: true),
        linha([for (final (i, p) in pontos.indexed) FlSpot(i.toDouble(), p.lucroBruto.toDouble())], coresGrafico[3]),
      ],
    ));
  }
}

/// Barras verticais simples (ex.: vendas por hora, faturamento por dia).
class GraficoBarras extends StatelessWidget {
  const GraficoBarras({super.key, required this.rotulos, required this.valores, this.cor = AppCores.ambar, this.formatarValor});

  final List<String> rotulos;
  final List<num> valores;
  final Color cor;
  final String Function(num)? formatarValor;

  @override
  Widget build(BuildContext context) {
    if (valores.every((v) => v == 0)) return const Center(child: Text('Sem dados no período'));
    final largura = (480 / valores.length).clamp(4, 28).toDouble();
    final intervalo = (valores.length / 12).ceilToDouble().clamp(1, 60).toDouble();
    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      titlesData: _titulos(
        intervaloInferior: intervalo,
        inferior: (v, meta) {
          final i = v.toInt();
          if (i < 0 || i >= rotulos.length || i % intervalo.toInt() != 0) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(rotulos[i], style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          );
        },
      ),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (grupo, _, barra, _) => BarTooltipItem(
            '${rotulos[grupo.x]}\n${(formatarValor ?? formatarMoeda)(barra.toY)}',
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
      ),
      barGroups: [
        for (final (i, v) in valores.indexed)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: v.toDouble(),
              color: cor,
              width: largura,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ]),
      ],
    ));
  }
}

/// Pizza com legenda (ex.: formas de pagamento).
class GraficoPizza extends StatelessWidget {
  const GraficoPizza({super.key, required this.rotulos, required this.valores});

  final List<String> rotulos;
  final List<num> valores;

  @override
  Widget build(BuildContext context) {
    final total = valores.fold<num>(0, (s, v) => s + v);
    if (total == 0) return const Center(child: Text('Sem dados no período'));
    return Row(children: [
      Expanded(
        child: PieChart(PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 42,
          sections: [
            for (final (i, v) in valores.indexed)
              PieChartSectionData(
                value: v.toDouble(),
                color: coresGrafico[i % coresGrafico.length],
                radius: 56,
                title: v / total >= 0.07 ? '${(v / total * 100).round()}%' : '',
                titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
              ),
          ],
        )),
      ),
      const SizedBox(width: 12),
      Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final (i, r) in rotulos.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: coresGrafico[i % coresGrafico.length], borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 8),
              Text(r, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              Text(moedaCompacta(valores[i]), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ]),
          ),
      ]),
    ]);
  }
}

/// Barras horizontais com valor (ex.: faturamento por categoria, top produtos).
class BarrasHorizontais extends StatelessWidget {
  const BarrasHorizontais({super.key, required this.itens, this.formatar});

  final List<(String, num, String?)> itens;
  final String Function(num)? formatar;

  @override
  Widget build(BuildContext context) {
    if (itens.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('Sem dados no período')));
    final maximo = itens.map((e) => e.$2).fold<num>(0, (a, b) => a > b ? a : b);
    return Column(children: [
      for (final (i, item) in itens.indexed)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(item.$1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
              if (item.$3 != null) Text(item.$3!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(width: 10),
              Text((formatar ?? formatarMoeda)(item.$2), style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: maximo == 0 ? 0 : (item.$2 / maximo).toDouble(),
                minHeight: 8,
                backgroundColor: Colors.grey.shade100,
                color: coresGrafico[i % coresGrafico.length],
              ),
            ),
          ]),
        ),
    ]);
  }
}
