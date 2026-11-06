import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/widgets/paginacao.dart';
import '../caixa/caixa.dart';
import 'venda_detalhe.dart';
import 'vendas.dart';

/// Histórico de vendas e acesso ao PDV.
class VendasPage extends ConsumerStatefulWidget {
  const VendasPage({super.key, this.caixaId});

  /// Filtra as vendas de um caixa (vindo do histórico de caixas).
  final String? caixaId;

  @override
  ConsumerState<VendasPage> createState() => _VendasPageState();
}

class _VendasPageState extends ConsumerState<VendasPage> {
  @override
  void initState() {
    super.initState();
    if (widget.caixaId != null) {
      Future.microtask(() => ref.read(filtroVendasProvider.notifier).caixa(widget.caixaId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtro = ref.watch(filtroVendasProvider);
    final controle = ref.read(filtroVendasProvider.notifier);
    final pagina = ref.watch(vendasProvider);
    final caixa = ref.watch(caixaAtualProvider).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CabecalhoPagina(
          titulo: 'Vendas',
          subtitulo: caixa == null
              ? 'Caixa fechado'
              : 'Caixa aberto · ${caixa.totais.quantidadeVendas} venda(s) · ${formatarMoeda(caixa.totais.totalVendas)}',
          acoes: [
            FilledButton.icon(
              onPressed: () => context.go('/pdv'),
              icon: const Icon(Icons.point_of_sale),
              label: const Text('Abrir PDV'),
            ),
          ],
        ),
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (filtro.caixaId != null)
            InputChip(
              avatar: const Icon(Icons.point_of_sale_outlined, size: 18),
              label: const Text('Vendas do caixa selecionado'),
              onDeleted: () => controle.caixa(null),
            )
          else
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text(filtro.periodo == null
                  ? 'Qualquer data'
                  : '${formatarData(filtro.periodo!.start)} a ${formatarData(filtro.periodo!.end)}'),
              onPressed: () async {
                final agora = DateTime.now();
                final periodo = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(agora.year - 5),
                  lastDate: agora,
                  initialDateRange: filtro.periodo,
                );
                if (periodo != null) controle.periodo(periodo);
              },
            ),
          RolavelNoCelular(child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '', label: Text('Todas')),
              ButtonSegment(value: 'CONCLUIDA', label: Text('Concluídas')),
              ButtonSegment(value: 'CANCELADA', label: Text('Canceladas')),
            ],
            selected: {filtro.status ?? ''},
            onSelectionChanged: (s) => controle.status(s.first.isEmpty ? null : s.first),
          )),
        ]),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: pagina.when(
            loading: () => const Carregando(),
            error: (e, _) => ErroView(mensagem: mensagemDeErro(e), aoTentarNovamente: () => ref.invalidate(vendasProvider)),
            data: (p) => p.conteudo.isEmpty
                ? const EstadoVazio(icone: Icons.receipt_long_outlined, titulo: 'Nenhuma venda no período')
                : Column(children: [
                    for (final (i, v) in p.conteudo.indexed) ...[
                      if (i > 0) const Divider(),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        onTap: () => abrirDetalheVenda(context, ref, v.id),
                        leading: CircleAvatar(
                          backgroundColor: (v.cancelada ? AppCores.perigo : AppCores.ambar).withValues(alpha: 0.15),
                          child: Icon(v.formaPagamento.icone, color: v.cancelada ? AppCores.perigo : AppCores.ambarEscuro),
                        ),
                        title: Text('Nº ${v.numero} · ${formatarDataHora(v.dataHora)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              decoration: v.cancelada ? TextDecoration.lineThrough : null,
                            )),
                        subtitle: Text(v.itens ?? '${v.quantidadeItens} item(ns)', maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(formatarMoeda(v.total), style: const TextStyle(fontWeight: FontWeight.w800)),
                          v.cancelada
                              ? const Etiqueta('Cancelada', cor: AppCores.perigo)
                              : Text(v.formaPagamento.rotulo, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ]),
                      ),
                    ],
                    const Divider(),
                    Paginacao(pagina: p, aoMudar: controle.pagina),
                  ]),
          ),
        ),
      ],
    );
  }
}
