import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'graficos.dart';
import 'relatorios.dart';

/// Relatórios gerenciais por período: indicadores, vendas por dia/hora/categoria,
/// formas de pagamento, produtos mais vendidos e lucrativos, baixo giro.
class RelatoriosPage extends ConsumerWidget {
  const RelatoriosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodo = ref.watch(periodoRelatorioProvider);
    final painel = ref.watch(painelRelatorioProvider);
    final controle = ref.read(periodoRelatorioProvider.notifier);
    final rapido = PeriodoRapido.values.where((r) {
      final i = r.intervalo();
      return DateUtils.isSameDay(i.start, periodo.start) && DateUtils.isSameDay(i.end, periodo.end);
    }).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CabecalhoPagina(
          titulo: 'Relatórios',
          subtitulo: '${formatarData(periodo.start)} a ${formatarData(periodo.end)}',
        ),
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          RolavelNoCelular(child: SegmentedButton<PeriodoRapido?>(
            emptySelectionAllowed: true,
            segments: [for (final r in PeriodoRapido.values) ButtonSegment(value: r, label: Text(r.rotulo))],
            selected: {if (rapido != null) rapido},
            onSelectionChanged: (s) {
              if (s.isNotEmpty && s.first != null) controle.mudar(s.first!.intervalo());
            },
          )),
          OutlinedButton.icon(
            icon: const Icon(Icons.date_range),
            label: const Text('Personalizado'),
            onPressed: () async {
              final agora = DateTime.now();
              final escolhido = await showDateRangePicker(
                context: context,
                firstDate: DateTime(agora.year - 3),
                lastDate: agora,
                initialDateRange: periodo,
              );
              if (escolhido != null) controle.mudar(escolhido);
            },
          ),
        ]),
        const SizedBox(height: 16),
        painel.when(
          loading: () => const Card(child: SizedBox(height: 240, child: Carregando())),
          error: (e, _) => Card(
            child: ErroView(mensagem: mensagemDeErro(e), aoTentarNovamente: () => ref.invalidate(painelRelatorioProvider)),
          ),
          data: (p) => _Relatorio(painel: p),
        ),
      ],
    );
  }
}

class _Relatorio extends StatelessWidget {
  const _Relatorio({required this.painel});

  final Painel painel;

  @override
  Widget build(BuildContext context) {
    final p = painel;
    final i = p.indicadores;
    final porDia = p.vendasPorDia.length > 1;
    return LayoutBuilder(builder: (context, c) {
      final largo = c.maxWidth >= 1050;
      Widget lado(Widget a, Widget b) => largo
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: a),
              const SizedBox(width: 16),
              Expanded(child: b),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, const SizedBox(height: 16), b]);

      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (p.demonstracao) const FaixaDemonstracao(),
        GradeResponsiva(larguraItem: 230, children: [
          CartaoIndicador(
            titulo: 'Faturamento',
            valor: formatarMoeda(i.faturamento),
            icone: Icons.payments_outlined,
            variacao: i.variacaoFaturamento,
            detalhe: 'vs. período anterior',
          ),
          CartaoIndicador(
            titulo: 'Vendas · ticket médio',
            valor: '${i.quantidadeVendas} · ${formatarMoeda(i.ticketMedio)}',
            icone: Icons.receipt_long,
            cor: coresGrafico[2],
          ),
          CartaoIndicador(
            titulo: 'Custo dos produtos (CMV)',
            valor: formatarMoeda(i.custo),
            icone: Icons.inventory_2_outlined,
            cor: coresGrafico[1],
          ),
          CartaoIndicador(
            titulo: 'Lucro bruto',
            valor: formatarMoeda(i.lucroBruto),
            icone: Icons.savings_outlined,
            detalhe: 'margem bruta ${formatarPercentual(i.margemBruta)}',
            cor: AppCores.sucesso,
          ),
          CartaoIndicador(
            titulo: 'Despesas',
            valor: formatarMoeda(i.despesas),
            icone: Icons.request_quote_outlined,
            cor: AppCores.perigo,
          ),
          CartaoIndicador(
            titulo: 'Lucro líquido estimado',
            valor: formatarMoeda(i.lucroLiquido),
            icone: Icons.account_balance_outlined,
            detalhe: 'lucro bruto − despesas',
            cor: i.lucroLiquido >= 0 ? AppCores.sucesso : AppCores.perigo,
          ),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            'Margem bruta considera apenas o custo dos produtos vendidos. O lucro líquido desconta as despesas '
            'registradas no período; só é completo se todas as despesas estiverem lançadas. '
            'Pedidos ainda não pagos e vendas canceladas não entram no faturamento.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
        if (porDia)
          PainelCard(
            titulo: 'Vendas por dia',
            subtitulo: 'Faturamento e lucro bruto',
            altura: 280,
            child: GraficoVendasDia(pontos: p.vendasPorDia),
          ),
        const SizedBox(height: 16),
        lado(
          PainelCard(
            titulo: 'Horários de maior movimento',
            altura: 240,
            child: GraficoBarras(
              rotulos: [for (final h in p.vendasPorHora) '${h.hora}h'],
              valores: [for (final h in p.vendasPorHora) h.faturamento],
              cor: coresGrafico[1],
            ),
          ),
          PainelCard(
            titulo: 'Formas de pagamento',
            altura: 240,
            child: GraficoPizza(
              rotulos: [for (final f in p.formasPagamento) '${f.rotulo} (${f.quantidade})'],
              valores: [for (final f in p.formasPagamento) f.total],
            ),
          ),
        ),
        const SizedBox(height: 16),
        lado(
          PainelCard(
            titulo: 'Vendas por categoria',
            subtitulo: 'Faturamento (lucro bruto ao lado)',
            child: BarrasHorizontais(
              itens: [for (final ct in p.porCategoria) (ct.categoria, ct.faturamento, 'lucro ${moedaCompacta(ct.lucroBruto)}')],
            ),
          ),
          PainelCard(
            titulo: 'Mais vendidos',
            subtitulo: 'Por quantidade',
            child: BarrasHorizontais(
              itens: [for (final r in p.maisVendidos) (r.produto, r.quantidade, moedaCompacta(r.faturamento))],
              formatar: (v) => '${formatarQuantidade(v)} un.',
            ),
          ),
        ),
        const SizedBox(height: 16),
        PainelCard(
          titulo: 'Produtos mais lucrativos',
          subtitulo: 'Custo, preço e lucro por unidade e no período',
          child: _Tabela(
            colunas: const ['Produto', 'Custo un.', 'Preço médio', 'Lucro un.', 'Margem', 'Qtd.', 'Lucro total'],
            linhas: [
              for (final r in p.maisLucrativos)
                [
                  r.produto,
                  formatarMoeda(r.custoUnitario),
                  formatarMoeda(r.precoMedio),
                  formatarMoeda(r.lucroUnitario),
                  formatarPercentual(r.margem),
                  formatarQuantidade(r.quantidade),
                  formatarMoeda(r.lucroBruto),
                ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        lado(
          PainelCard(
            titulo: 'Baixo giro',
            subtitulo: 'Produtos que menos venderam no período',
            child: _Tabela(
              colunas: const ['Produto', 'Vendidos', 'Em estoque', 'Valor parado'],
              linhas: [
                for (final g in p.baixoGiro)
                  [
                    g.produto,
                    formatarQuantidade(g.quantidadeVendida),
                    g.estoqueAtual == null ? '—' : '${formatarQuantidade(g.estoqueAtual)} ${g.unidade}',
                    formatarMoeda(g.valorParado),
                  ],
              ],
            ),
          ),
          PainelCard(
            titulo: 'Estoque',
            subtitulo: 'Valor estimado: ${formatarMoeda(p.valorEstoque)} · ${p.produtosAbaixoMinimo} abaixo do mínimo',
            child: _Tabela(
              colunas: const ['Produto', 'Atual', 'Mínimo'],
              linhas: [
                for (final e in p.abaixoMinimo)
                  [e.produto, '${formatarQuantidade(e.atual)} ${e.unidade}', '${formatarQuantidade(e.minimo)} ${e.unidade}'],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Gerado em ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ]);
    });
  }
}

class _Tabela extends StatelessWidget {
  const _Tabela({required this.colunas, required this.linhas});

  final List<String> colunas;
  final List<List<String>> linhas;

  @override
  Widget build(BuildContext context) {
    if (linhas.isEmpty) {
      return const Padding(padding: EdgeInsets.all(12), child: Text('Sem dados no período'));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 38,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 44,
        columnSpacing: 22,
        headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF6B7280)),
        columns: [
          for (final (i, c) in colunas.indexed) DataColumn(label: Text(c), numeric: i > 0),
        ],
        rows: [
          for (final l in linhas) DataRow(cells: [for (final v in l) DataCell(Text(v))]),
        ],
      ),
    );
  }
}
