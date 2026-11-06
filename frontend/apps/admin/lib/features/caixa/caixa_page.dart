import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'caixa.dart';
import 'caixa_dialogos.dart';

class CaixaPage extends ConsumerWidget {
  const CaixaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final atual = ref.watch(caixaAtualProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CabecalhoPagina(titulo: 'Caixa', subtitulo: 'Abertura, suprimentos, retiradas e fechamento do turno'),
        atual.when(
          loading: () => const Card(child: Carregando()),
          error: (e, _) => Card(
            child: ErroView(mensagem: mensagemDeErro(e), aoTentarNovamente: () => ref.invalidate(caixaAtualProvider)),
          ),
          data: (caixa) => caixa == null ? const _CaixaFechado() : _CaixaAberto(caixa: caixa),
        ),
        const SizedBox(height: 28),
        Text('Caixas anteriores', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        const _Historico(),
      ],
    );
  }
}

class _CaixaFechado extends ConsumerWidget {
  const _CaixaFechado();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: EstadoVazio(
        icone: Icons.point_of_sale_outlined,
        titulo: 'Nenhum caixa aberto',
        descricao: 'Abra o caixa para começar a registrar vendas.',
        acao: FilledButton.icon(
          onPressed: () => abrirCaixa(context, ref),
          icon: const Icon(Icons.lock_open),
          label: const Text('Abrir caixa'),
        ),
      ),
    );
  }
}

class _CaixaAberto extends ConsumerWidget {
  const _CaixaAberto({required this.caixa});

  final Caixa caixa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        const Etiqueta('Caixa aberto', cor: AppCores.sucesso, icone: Icons.lock_open),
        Text('desde ${formatarDataHora(caixa.abertoEm)} · saldo inicial ${formatarMoeda(caixa.saldoInicial)}'),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: () => context.go('/pdv'),
          icon: const Icon(Icons.point_of_sale),
          label: const Text('Abrir PDV'),
        ),
        OutlinedButton.icon(
          onPressed: () => movimentarCaixa(context, ref, suprimento: true),
          icon: const Icon(Icons.add),
          label: const Text('Suprimento'),
        ),
        OutlinedButton.icon(
          onPressed: () => movimentarCaixa(context, ref, suprimento: false),
          icon: const Icon(Icons.remove),
          label: const Text('Retirada'),
        ),
        OutlinedButton.icon(
          onPressed: () => fecharCaixa(context, ref, caixa),
          style: OutlinedButton.styleFrom(foregroundColor: AppCores.perigo),
          icon: const Icon(Icons.lock),
          label: const Text('Fechar caixa'),
        ),
      ]),
      const SizedBox(height: 16),
      ResumoCaixa(caixa: caixa),
      if (caixa.movimentacoes.isNotEmpty) ...[
        const SizedBox(height: 16),
        Card(
          child: Column(children: [
            for (final (i, m) in caixa.movimentacoes.indexed) ...[
              if (i > 0) const Divider(),
              ListTile(
                leading: Icon(m.suprimento ? Icons.south_west : Icons.north_east,
                    color: m.suprimento ? AppCores.sucesso : AppCores.perigo),
                title: Text('${m.suprimento ? 'Suprimento' : 'Retirada'} · ${m.motivo}'),
                subtitle: Text(formatarDataHora(m.dataHora)),
                trailing: Text('${m.suprimento ? '+' : '−'}${formatarMoeda(m.valor)}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
        ),
      ],
    ]);
  }
}

/// Cartões com os totais do caixa (usado no caixa aberto e no detalhe do histórico).
class ResumoCaixa extends StatelessWidget {
  const ResumoCaixa({super.key, required this.caixa});

  final Caixa caixa;

  @override
  Widget build(BuildContext context) {
    final t = caixa.totais;
    Widget cartao(String titulo, String valor, {Color? cor, String? ajuda}) => SizedBox(
          width: double.infinity,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titulo, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(valor, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: cor)),
                ),
                if (ajuda != null) Text(ajuda, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              ]),
            ),
          ),
        );
    return GradeResponsiva(larguraItem: 170, children: [
      cartao('Vendas', formatarMoeda(t.totalVendas),
          ajuda: '${t.quantidadeVendas} venda(s)${caixa.vendasCanceladas > 0 ? ' · ${caixa.vendasCanceladas} cancelada(s)' : ''}'),
      cartao('Lucro bruto', formatarMoeda(caixa.lucroBruto), cor: AppCores.sucesso, ajuda: 'vendas − custo'),
      cartao('Dinheiro', formatarMoeda(t.dinheiro)),
      cartao('PIX', formatarMoeda(t.pix)),
      cartao('Cartão de débito', formatarMoeda(t.cartaoDebito)),
      cartao('Cartão de crédito', formatarMoeda(t.cartaoCredito)),
      cartao('Outros', formatarMoeda(t.outros)),
      cartao('Suprimentos', formatarMoeda(t.suprimentos)),
      cartao('Retiradas', formatarMoeda(t.retiradas)),
      cartao('Dinheiro esperado', formatarMoeda(t.saldoEsperado),
          cor: AppCores.ambarEscuro, ajuda: 'na gaveta'),
      if (!caixa.aberto) ...[
        cartao('Dinheiro contado', formatarMoeda(caixa.saldoContado)),
        cartao('Diferença', formatarMoeda(caixa.diferenca),
            cor: (caixa.diferenca ?? 0) == 0 ? AppCores.sucesso : AppCores.perigo),
      ],
    ]);
  }
}

class _Historico extends ConsumerWidget {
  const _Historico();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historico = ref.watch(historicoCaixasProvider);
    return Card(
      child: historico.when(
        loading: () => const Carregando(),
        error: (e, _) => ErroView(mensagem: mensagemDeErro(e)),
        data: (p) {
          final fechados = p.conteudo.where((c) => !c.aberto).toList();
          if (fechados.isEmpty) {
            return const EstadoVazio(icone: Icons.history, titulo: 'Nenhum caixa fechado ainda');
          }
          return Column(children: [
            for (final (i, c) in fechados.indexed) ...[
              if (i > 0) const Divider(),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                title: Text('${formatarDataHora(c.abertoEm)} → ${formatarDataHora(c.fechadoEm)}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${c.totais.quantidadeVendas} venda(s) · ${formatarMoeda(c.totais.totalVendas)}'),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('diferença', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  Text(formatarMoeda(c.diferenca),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: (c.diferenca ?? 0) == 0 ? AppCores.sucesso : AppCores.perigo,
                      )),
                ]),
                onTap: () => _detalhe(context, ref, c.id),
              ),
            ],
          ]);
        },
      ),
    );
  }

  Future<void> _detalhe(BuildContext context, WidgetRef ref, String id) async {
    try {
      final caixa = await ref.read(caixaRepositoryProvider).buscar(id);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Caixa de ${formatarData(caixa.abertoEm)}'),
          content: SizedBox(
            width: 760,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                Text('${formatarDataHora(caixa.abertoEm)} → ${formatarDataHora(caixa.fechadoEm)}'),
                if (caixa.observacaoFechamento != null) Text('Obs.: ${caixa.observacaoFechamento}'),
                const SizedBox(height: 12),
                ResumoCaixa(caixa: caixa),
              ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/vendas?caixaId=${caixa.id}');
              },
              child: const Text('Ver vendas'),
            ),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) mostrarErro(context, e);
    }
  }
}
