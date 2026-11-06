import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/widgets/paginacao.dart';
import '../categorias/categorias.dart';
import 'estoque.dart';
import 'movimento_dialog.dart';

class EstoquePage extends ConsumerWidget {
  const EstoquePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final secao = ref.watch(secaoEstoqueProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CabecalhoPagina(
          titulo: 'Estoque',
          subtitulo: 'Saldos, movimentações e inventários. Toda alteração fica registrada no histórico.',
        ),
        const _CartoesResumo(),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<SecaoEstoque>(
            segments: const [
              ButtonSegment(value: SecaoEstoque.posicao, icon: Icon(Icons.inventory_2_outlined), label: Text('Posição')),
              ButtonSegment(value: SecaoEstoque.movimentacoes, icon: Icon(Icons.swap_vert), label: Text('Movimentações')),
              ButtonSegment(value: SecaoEstoque.inventarios, icon: Icon(Icons.fact_check_outlined), label: Text('Inventários')),
            ],
            selected: {secao},
            onSelectionChanged: (s) => ref.read(secaoEstoqueProvider.notifier).mudar(s.first),
          ),
        ),
        const SizedBox(height: 16),
        switch (secao) {
          SecaoEstoque.posicao => const _SecaoPosicao(),
          SecaoEstoque.movimentacoes => const _SecaoMovimentacoes(),
          SecaoEstoque.inventarios => const _SecaoInventarios(),
        },
      ],
    );
  }
}

// =============================================================================
// Resumo
// =============================================================================

class _CartoesResumo extends ConsumerWidget {
  const _CartoesResumo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumo = ref.watch(resumoEstoqueProvider).value;
    void filtrar(SituacaoEstoque s) {
      ref.read(secaoEstoqueProvider.notifier).mudar(SecaoEstoque.posicao);
      ref.read(filtroPosicaoProvider.notifier).situacao(s);
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _Cartao(
          icone: Icons.attach_money,
          titulo: 'Valor em estoque',
          valor: resumo == null ? '…' : formatarMoeda(resumo.valorTotal),
          ajuda: 'Quantidade × custo de aquisição',
        ),
        _Cartao(
          icone: Icons.inventory_2_outlined,
          titulo: 'Produtos ativos',
          valor: resumo == null ? '…' : '${resumo.produtosAtivos}',
          aoTocar: () => filtrar(SituacaoEstoque.todos),
        ),
        _Cartao(
          icone: Icons.warning_amber_rounded,
          titulo: 'Abaixo do mínimo',
          valor: resumo == null ? '…' : '${resumo.abaixoMinimo}',
          cor: (resumo?.abaixoMinimo ?? 0) > 0 ? AppCores.alerta : null,
          aoTocar: () => filtrar(SituacaoEstoque.abaixoMinimo),
        ),
        _Cartao(
          icone: Icons.remove_shopping_cart_outlined,
          titulo: 'Zerados',
          valor: resumo == null ? '…' : '${resumo.zerados}',
          cor: (resumo?.zerados ?? 0) > 0 ? AppCores.perigo : null,
          aoTocar: () => filtrar(SituacaoEstoque.zerado),
        ),
      ],
    );
  }
}

class _Cartao extends StatelessWidget {
  const _Cartao({required this.icone, required this.titulo, required this.valor, this.ajuda, this.cor, this.aoTocar});

  final IconData icone;
  final String titulo;
  final String valor;
  final String? ajuda;
  final Color? cor;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: aoTocar,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icone, size: 18, color: cor ?? Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(child: Text(titulo, style: TextStyle(color: Colors.grey.shade700, fontSize: 13))),
                ]),
                const SizedBox(height: 8),
                Text(valor, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: cor)),
                if (ajuda != null) Text(ajuda!, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Posição
// =============================================================================

class _SecaoPosicao extends ConsumerStatefulWidget {
  const _SecaoPosicao();

  @override
  ConsumerState<_SecaoPosicao> createState() => _SecaoPosicaoState();
}

class _SecaoPosicaoState extends ConsumerState<_SecaoPosicao> {
  late final _busca = TextEditingController(text: ref.read(filtroPosicaoProvider).nome);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtro = ref.watch(filtroPosicaoProvider);
    final controle = ref.read(filtroPosicaoProvider.notifier);
    final categorias = ref.watch(categoriasProvider).value ?? const <Categoria>[];
    final pagina = ref.watch(posicaoEstoqueProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 300,
              child: TextField(
                controller: _busca,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Produto ou código'),
                onChanged: (t) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 400), () => controle.nome(t.trim()));
                },
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String?>(
                key: ValueKey(categorias.length),
                initialValue: categorias.any((c) => c.id == filtro.categoriaId) ? filtro.categoriaId : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todas')),
                  for (final c in categorias) DropdownMenuItem(value: c.id, child: Text(c.nome)),
                ],
                onChanged: controle.categoria,
              ),
            ),
            SegmentedButton<SituacaoEstoque>(
              segments: [
                for (final s in SituacaoEstoque.values) ButtonSegment(value: s, label: Text(s.rotulo)),
              ],
              selected: {filtro.situacao},
              onSelectionChanged: (s) => controle.situacao(s.first),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: pagina.when(
            loading: () => const Carregando(),
            error: (e, _) => ErroView(
              mensagem: mensagemDeErro(e),
              aoTentarNovamente: () => ref.invalidate(posicaoEstoqueProvider),
            ),
            data: (p) => p.conteudo.isEmpty
                ? const EstadoVazio(icone: Icons.inventory_2_outlined, titulo: 'Nenhum produto encontrado')
                : LayoutBuilder(builder: (context, c) {
                    final largo = c.maxWidth >= 900;
                    return Column(children: [
                      if (largo) const _CabecalhoPosicao(),
                      for (final (i, item) in p.conteudo.indexed) ...[
                        if (i > 0 || largo) const Divider(),
                        largo ? _LinhaPosicao(item: item) : _CartaoPosicao(item: item),
                      ],
                      const Divider(),
                      Paginacao(pagina: p, aoMudar: controle.pagina),
                    ]);
                  }),
          ),
        ),
      ],
    );
  }
}

const _estiloCabecalho = TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF6B7280));

class _CabecalhoPosicao extends StatelessWidget {
  const _CabecalhoPosicao();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(children: [
        Expanded(flex: 4, child: Text('PRODUTO', style: _estiloCabecalho)),
        Expanded(flex: 2, child: Text('SALDO', style: _estiloCabecalho, textAlign: TextAlign.right)),
        Expanded(flex: 2, child: Text('MÍNIMO', style: _estiloCabecalho, textAlign: TextAlign.right)),
        Expanded(flex: 2, child: Text('CUSTO', style: _estiloCabecalho, textAlign: TextAlign.right)),
        Expanded(flex: 2, child: Text('VALOR', style: _estiloCabecalho, textAlign: TextAlign.right)),
        SizedBox(width: 180),
      ]),
    );
  }
}

class _Saldo extends StatelessWidget {
  const _Saldo({required this.item, this.alinhamento = TextAlign.right});

  final PosicaoEstoque item;
  final TextAlign alinhamento;

  @override
  Widget build(BuildContext context) {
    final texto = '${formatarQuantidade(item.quantidade)} ${item.unidadeSigla}';
    final cor = item.zerado ? AppCores.perigo : (item.abaixoMinimo ? AppCores.alerta : null);
    return Column(
      crossAxisAlignment: alinhamento == TextAlign.right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(texto, style: TextStyle(fontWeight: FontWeight.w700, color: cor)),
        if (item.reservada > 0)
          Text('${formatarQuantidade(item.reservada)} reservado(s)',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }
}

class _AcoesPosicao extends ConsumerWidget {
  const _AcoesPosicao({required this.item});

  final PosicaoEstoque item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void abrir(ModoMovimento modo) => abrirMovimento(context, ref, produtoId: item.produtoId, modo: modo);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Entrada',
          icon: const Icon(Icons.add_circle_outline, color: AppCores.sucesso),
          onPressed: () => abrir(ModoMovimento.entrada),
        ),
        IconButton(
          tooltip: 'Saída (consumo, perda, devolução)',
          icon: const Icon(Icons.remove_circle_outline, color: AppCores.perigo),
          onPressed: () => abrir(ModoMovimento.saida),
        ),
        IconButton(
          tooltip: 'Ajustar (contagem)',
          icon: const Icon(Icons.tune),
          onPressed: () => abrir(ModoMovimento.ajuste),
        ),
        IconButton(
          tooltip: 'Histórico',
          icon: const Icon(Icons.history),
          onPressed: () {
            ref.read(filtroMovimentacoesProvider.notifier).produto(item.produtoId, item.nome);
            ref.read(secaoEstoqueProvider.notifier).mudar(SecaoEstoque.movimentacoes);
          },
        ),
      ],
    );
  }
}

class _LinhaPosicao extends StatelessWidget {
  const _LinhaPosicao({required this.item});

  final PosicaoEstoque item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(children: [
        Expanded(
          flex: 4,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(item.categoria ?? 'Sem categoria', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ]),
        ),
        Expanded(flex: 2, child: _Saldo(item: item)),
        Expanded(
          flex: 2,
          child: Text(item.estoqueMinimo > 0 ? '${formatarQuantidade(item.estoqueMinimo)} ${item.unidadeSigla}' : '—',
              textAlign: TextAlign.right),
        ),
        Expanded(
          flex: 2,
          child: Text('${formatarMoeda(item.custoMedio)}/${item.unidadeSigla}', textAlign: TextAlign.right),
        ),
        Expanded(flex: 2, child: Text(formatarMoeda(item.valorEstoque), textAlign: TextAlign.right)),
        SizedBox(width: 180, child: Align(alignment: Alignment.centerRight, child: _AcoesPosicao(item: item))),
      ]),
    );
  }
}

class _CartaoPosicao extends StatelessWidget {
  const _CartaoPosicao({required this.item});

  final PosicaoEstoque item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(item.nome, style: const TextStyle(fontWeight: FontWeight.w600))),
          _Saldo(item: item),
        ]),
        Text(
          [
            item.categoria ?? 'Sem categoria',
            if (item.estoqueMinimo > 0) 'mín. ${formatarQuantidade(item.estoqueMinimo)}',
            formatarMoeda(item.valorEstoque),
          ].join(' · '),
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        Align(alignment: Alignment.centerRight, child: _AcoesPosicao(item: item)),
      ]),
    );
  }
}

// =============================================================================
// Movimentações
// =============================================================================

class _SecaoMovimentacoes extends ConsumerWidget {
  const _SecaoMovimentacoes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtro = ref.watch(filtroMovimentacoesProvider);
    final controle = ref.read(filtroMovimentacoesProvider.notifier);
    final pagina = ref.watch(movimentacoesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (filtro.produtoId != null)
              InputChip(
                avatar: const Icon(Icons.inventory_2_outlined, size: 18),
                label: Text(filtro.produtoNome ?? 'Produto'),
                onDeleted: () => controle.produto(null, null),
              ),
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<TipoMovimentacao?>(
                initialValue: filtro.tipo,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos')),
                  for (final t in TipoMovimentacao.values) DropdownMenuItem(value: t, child: Text(t.rotulo)),
                ],
                onChanged: controle.tipo,
              ),
            ),
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
            if (filtro.periodo != null)
              IconButton(tooltip: 'Limpar período', icon: const Icon(Icons.close), onPressed: () => controle.periodo(null)),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: pagina.when(
            loading: () => const Carregando(),
            error: (e, _) => ErroView(
              mensagem: mensagemDeErro(e),
              aoTentarNovamente: () => ref.invalidate(movimentacoesProvider),
            ),
            data: (p) => p.conteudo.isEmpty
                ? const EstadoVazio(icone: Icons.swap_vert, titulo: 'Nenhuma movimentação encontrada')
                : Column(children: [
                    for (final (i, m) in p.conteudo.indexed) ...[
                      if (i > 0) const Divider(),
                      _LinhaMovimentacao(m: m),
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

class _LinhaMovimentacao extends StatelessWidget {
  const _LinhaMovimentacao({required this.m});

  final Movimentacao m;

  @override
  Widget build(BuildContext context) {
    final cor = m.entrada ? AppCores.sucesso : AppCores.perigo;
    final sinal = m.entrada ? '+' : '−';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: cor.withValues(alpha: 0.12),
        child: Icon(m.entrada ? Icons.south_west : Icons.north_east, color: cor, size: 20),
      ),
      title: Text(m.produtoNome, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Etiqueta(m.tipo.rotulo, cor: cor),
          Text(formatarDataHora(m.dataHora)),
          if (m.quantidadeInformada != null) Text('informado: ${m.quantidadeInformada}'),
          if (m.observacao != null) Text('“${m.observacao}”', style: const TextStyle(fontStyle: FontStyle.italic)),
        ]),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('$sinal${formatarQuantidade(m.quantidade.abs())} ${m.unidadeSigla}',
              style: TextStyle(fontWeight: FontWeight.w700, color: cor)),
          Text('${formatarQuantidade(m.saldoAnterior)} → ${formatarQuantidade(m.saldoPosterior)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

// =============================================================================
// Inventários
// =============================================================================

class _SecaoInventarios extends ConsumerWidget {
  const _SecaoInventarios();

  Future<void> _novo(BuildContext context, WidgetRef ref) async {
    final id = await showDialog<String>(context: context, builder: (_) => const _NovoInventarioDialog());
    if (id != null && context.mounted) {
      ref.invalidate(inventariosProvider);
      context.go('/estoque/inventarios/$id');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventarios = ref.watch(inventariosProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: Text(
              'Conte o estoque físico e o sistema ajusta as diferenças. Pode salvar a contagem aos poucos.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          FilledButton.icon(
            onPressed: () => _novo(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Novo inventário'),
          ),
        ]),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: inventarios.when(
            loading: () => const Carregando(),
            error: (e, _) => ErroView(
              mensagem: mensagemDeErro(e),
              aoTentarNovamente: () => ref.invalidate(inventariosProvider),
            ),
            data: (p) => p.conteudo.isEmpty
                ? const EstadoVazio(icone: Icons.fact_check_outlined, titulo: 'Nenhum inventário realizado')
                : Column(children: [
                    for (final (i, inv) in p.conteudo.indexed) ...[
                      if (i > 0) const Divider(),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        leading: const CircleAvatar(child: Icon(Icons.fact_check_outlined)),
                        title: Text(inv.descricao, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text([
                          inv.categoria ?? 'Todas as categorias',
                          'aberto em ${formatarDataHora(inv.criadoEm)}',
                          '${inv.itensContados}/${inv.totalItens} contados',
                        ].join(' · ')),
                        trailing: Etiqueta(
                          inv.status.rotulo,
                          cor: switch (inv.status) {
                            StatusInventario.aberto => AppCores.ambarEscuro,
                            StatusInventario.concluido => AppCores.sucesso,
                            StatusInventario.cancelado => Colors.grey.shade600,
                          },
                        ),
                        onTap: () => context.go('/estoque/inventarios/${inv.id}'),
                      ),
                    ],
                  ]),
          ),
        ),
      ],
    );
  }
}

class _NovoInventarioDialog extends ConsumerStatefulWidget {
  const _NovoInventarioDialog();

  @override
  ConsumerState<_NovoInventarioDialog> createState() => _NovoInventarioDialogState();
}

class _NovoInventarioDialogState extends ConsumerState<_NovoInventarioDialog> {
  final _descricao = TextEditingController(text: 'Inventário de ${formatarData(DateTime.now())}');
  String? _categoriaId;
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _descricao.dispose();
    super.dispose();
  }

  Future<void> _criar() async {
    if (_descricao.text.trim().isEmpty) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      final inv = await ref.read(estoqueRepositoryProvider).criarInventario(_descricao.text.trim(), _categoriaId);
      if (mounted) Navigator.pop(context, inv.id);
    } catch (e) {
      setState(() => _erro = mensagemDeErro(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categorias = (ref.watch(categoriasProvider).value ?? const <Categoria>[]).where((c) => c.ativo).toList();
    return AlertDialog(
      title: const Text('Novo inventário'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _descricao,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Descrição'),
          ),
          DropdownButtonFormField<String?>(
            initialValue: _categoriaId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Produtos',
              helperText: 'Inventariar tudo ou apenas uma categoria',
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Todos os produtos ativos')),
              for (final c in categorias) DropdownMenuItem(value: c.id, child: Text('Somente ${c.nome}')),
            ],
            onChanged: (v) => setState(() => _categoriaId = v),
          ),
          if (_erro != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_erro!, style: const TextStyle(color: AppCores.perigo)),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _salvando ? null : _criar, child: const Text('Abrir inventário')),
      ],
    );
  }
}
