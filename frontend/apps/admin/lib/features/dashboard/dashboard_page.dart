import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../relatorios/graficos.dart';
import '../relatorios/relatorios.dart';

/// Visão geral da operação: indicadores do dia e do mês, tendência dos últimos 30 dias,
/// formas de pagamento, horários de pico, produtos e alertas de estoque.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final painel = ref.watch(painelDashboardProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CabecalhoPagina(
          titulo: 'Dashboard',
          subtitulo: 'Visão geral dos últimos 30 dias',
          acoes: [
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(painelDashboardProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Atualizar'),
            ),
            FilledButton.icon(
              onPressed: () => context.go('/pdv'),
              icon: const Icon(Icons.point_of_sale),
              label: const Text('Abrir PDV'),
            ),
          ],
        ),
        painel.when(
          loading: () => const Card(child: SizedBox(height: 240, child: Carregando())),
          error: (e, _) => Card(
            child: ErroView(mensagem: mensagemDeErro(e), aoTentarNovamente: () => ref.invalidate(painelDashboardProvider)),
          ),
          data: (p) => _Conteudo(painel: p),
        ),
      ],
    );
  }
}

class _Conteudo extends StatelessWidget {
  const _Conteudo({required this.painel});

  final Painel painel;

  @override
  Widget build(BuildContext context) {
    final p = painel;
    final i = p.indicadores;
    return LayoutBuilder(builder: (context, c) {
      final largo = c.maxWidth >= 1050;
      Widget lado(Widget a, Widget b, {int fa = 3, int fb = 2}) => largo
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: fa, child: a),
              const SizedBox(width: 16),
              Expanded(flex: fb, child: b),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, const SizedBox(height: 16), b]);

      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (p.demonstracao) const FaixaDemonstracao(),
        Wrap(spacing: 12, runSpacing: 12, children: [
          CartaoIndicador(
            titulo: 'Faturamento hoje',
            valor: formatarMoeda(i.faturamentoHoje),
            icone: Icons.today,
            detalhe: '${i.vendasHoje} venda(s)',
          ),
          CartaoIndicador(
            titulo: 'Faturamento do mês',
            valor: formatarMoeda(i.faturamentoMes),
            icone: Icons.calendar_month,
            detalhe: '${i.vendasMes} venda(s)',
            cor: coresGrafico[2],
          ),
          CartaoIndicador(
            titulo: 'Últimos 30 dias',
            valor: formatarMoeda(i.faturamento),
            icone: Icons.show_chart,
            variacao: i.variacaoFaturamento,
            detalhe: 'vs. 30 dias anteriores',
            cor: coresGrafico[1],
          ),
          CartaoIndicador(
            titulo: 'Ticket médio',
            valor: formatarMoeda(i.ticketMedio),
            icone: Icons.receipt_long,
            detalhe: '${i.quantidadeVendas} vendas no período',
            cor: coresGrafico[4],
          ),
          CartaoIndicador(
            titulo: 'Lucro bruto',
            valor: formatarMoeda(i.lucroBruto),
            icone: Icons.savings_outlined,
            detalhe: 'margem ${formatarPercentual(i.margemBruta)}',
            cor: AppCores.sucesso,
          ),
          CartaoIndicador(
            titulo: 'Estoque abaixo do mínimo',
            valor: '${p.produtosAbaixoMinimo}',
            icone: Icons.warning_amber_rounded,
            detalhe: 'estoque vale ${moedaCompacta(p.valorEstoque)}',
            cor: p.produtosAbaixoMinimo > 0 ? AppCores.perigo : AppCores.sucesso,
          ),
        ]),
        const SizedBox(height: 16),
        lado(
          PainelCard(
            titulo: 'Faturamento e lucro bruto por dia',
            subtitulo: 'Âmbar: faturamento · Verde: lucro bruto',
            altura: 280,
            child: GraficoVendasDia(pontos: p.vendasPorDia),
          ),
          PainelCard(
            titulo: 'Formas de pagamento',
            altura: 280,
            child: GraficoPizza(
              rotulos: [for (final f in p.formasPagamento) f.rotulo],
              valores: [for (final f in p.formasPagamento) f.total],
            ),
          ),
        ),
        const SizedBox(height: 16),
        lado(
          PainelCard(
            titulo: 'Horários de maior movimento',
            subtitulo: 'Faturamento por hora do dia',
            altura: 240,
            child: GraficoBarras(
              rotulos: [for (final h in p.vendasPorHora) '${h.hora}h'],
              valores: [for (final h in p.vendasPorHora) h.faturamento],
              cor: coresGrafico[1],
            ),
          ),
          PainelCard(
            titulo: 'Mais vendidos',
            subtitulo: 'Quantidade no período',
            child: BarrasHorizontais(
              itens: [for (final r in p.maisVendidos.take(6)) (r.produto, r.quantidade, moedaCompacta(r.faturamento))],
              formatar: (v) => '${formatarQuantidade(v)} un.',
            ),
          ),
          fa: 3,
          fb: 2,
        ),
        const SizedBox(height: 16),
        lado(
          PainelCard(
            titulo: 'Produtos mais lucrativos',
            subtitulo: 'Lucro bruto no período (preço − custo)',
            child: BarrasHorizontais(
              itens: [for (final r in p.maisLucrativos.take(6)) (r.produto, r.lucroBruto, 'margem ${formatarPercentual(r.margem)}')],
            ),
          ),
          PainelCard(
            titulo: 'Alertas de estoque',
            subtitulo: p.produtosAbaixoMinimo == 0 ? 'Tudo acima do mínimo' : '${p.produtosAbaixoMinimo} produto(s) abaixo do mínimo',
            child: p.abaixoMinimo.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(children: [
                      Icon(Icons.check_circle, color: AppCores.sucesso),
                      SizedBox(width: 8),
                      Text('Nenhum produto abaixo do mínimo'),
                    ]),
                  )
                : Column(children: [
                    for (final e in p.abaixoMinimo.take(6))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.warning_amber_rounded, color: AppCores.alerta),
                        title: Text(e.produto),
                        trailing: Text('${formatarQuantidade(e.atual)} / ${formatarQuantidade(e.minimo)} ${e.unidade}',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppCores.perigo)),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(onPressed: () => context.go('/compras'), child: const Text('Ver sugestões de compra')),
                    ),
                  ]),
          ),
        ),
      ]);
    });
  }
}
