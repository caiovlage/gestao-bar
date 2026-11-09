import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../caixa/caixa.dart';
import '../estoque/estoque.dart';
import '../pedidos/pedidos_page.dart' show pedirMotivo;
import '../vendas/vendas.dart';
import 'comandas.dart';
import 'comandas_page.dart' show DialogoComanda;

/// Uma comanda: itens lançados (com + / − / remover), catálogo para lançar (busca, leitor de código
/// ou toque no produto) e fechamento da conta.
class ComandaPage extends ConsumerStatefulWidget {
  const ComandaPage({super.key, required this.comandaId});

  final String comandaId;

  @override
  ConsumerState<ComandaPage> createState() => _ComandaPageState();
}

class _ComandaPageState extends ConsumerState<ComandaPage> {
  Comanda? _atual;
  bool _ocupado = false;

  /// Executa uma ação na API e mostra o estado devolvido (sem recarregar a tela).
  Future<void> _executar(Future<Comanda> Function(ComandasRepository r) acao, {String? sucesso}) async {
    setState(() => _ocupado = true);
    try {
      final c = await acao(ref.read(comandasRepositoryProvider));
      if (!mounted) return;
      setState(() => _atual = c);
      ref.invalidate(comandasAbertasProvider);
      ref.invalidate(catalogoPdvProvider);
      ref.invalidate(posicaoEstoqueProvider);
      if (sucesso != null) mostrarSucesso(context, sucesso);
    } catch (e) {
      if (mounted) mostrarErro(context, e);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _lancar(Comanda c, ItemCatalogo p, {num quantidade = 1, String? observacao}) async {
    if (p.esgotado) {
      mostrarErro(context, '${p.nome} está sem estoque.');
      return;
    }
    await _executar((r) => r.lancar(c.id, p.produtoId, quantidade: quantidade, observacao: observacao));
  }

  Future<void> _fechar(Comanda c) async {
    final fechada = await showDialog<Comanda>(context: context, builder: (_) => _FecharContaDialog(comanda: c));
    if (fechada == null || !mounted) return;
    ref.invalidate(comandasAbertasProvider);
    ref.invalidate(historicoComandasProvider);
    ref.invalidate(caixaAtualProvider);
    ref.invalidate(vendasProvider);
    ref.invalidate(catalogoPdvProvider);
    ref.invalidate(posicaoEstoqueProvider);
    mostrarSucesso(context, 'Conta da comanda nº ${c.numero} fechada: venda registrada no caixa.');
    context.go('/comandas');
  }

  Future<void> _cancelar(Comanda c) async {
    final motivo = await pedirMotivo(context,
        titulo: 'Cancelar comanda nº ${c.numero}', dica: 'Ex.: aberta por engano', acao: 'Cancelar comanda');
    if (motivo == null) return;
    await _executar((r) => r.cancelar(c.id, motivo), sucesso: 'Comanda cancelada. Reservas de estoque devolvidas.');
    ref.invalidate(historicoComandasProvider);
    if (mounted) context.go('/comandas');
  }

  @override
  Widget build(BuildContext context) {
    final carregada = ref.watch(comandaProvider(widget.comandaId));
    return carregada.when(
      loading: () => const Card(child: Carregando()),
      error: (e, _) => Card(
        child: ErroView(
          mensagem: mensagemDeErro(e),
          aoTentarNovamente: () => ref.invalidate(comandaProvider(widget.comandaId)),
        ),
      ),
      data: (inicial) => _conteudo(_atual ?? inicial),
    );
  }

  Widget _conteudo(Comanda c) {
    final itens = _PainelItens(
      comanda: c,
      ocupado: _ocupado,
      aoMais: (i) => _executar((r) => r.lancar(c.id, i.produtoId, observacao: i.observacao)),
      aoMenos: (i) => _executar((r) => r.retirar(c.id, i.id, quantidade: 1)),
      aoRemover: (i) => _executar((r) => r.retirar(c.id, i.id)),
      aoFechar: () => _fechar(c),
    );
    final catalogo = c.aberta
        ? _Catalogo(
            aoLancar: (p, {quantidade = 1, observacao}) =>
                _lancar(c, p, quantidade: quantidade, observacao: observacao),
          )
        : null;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CabecalhoPagina(
        titulo: 'Comanda nº ${c.numero} · ${c.clienteNome}',
        subtitulo: [
          if (c.local != null) c.local!,
          'aberta em ${formatarDataHora(c.abertaEm)}',
          if (!c.aberta) c.status == StatusComanda.fechada ? 'FECHADA' : 'CANCELADA',
        ].join(' · '),
        acoes: [
          OutlinedButton.icon(
            onPressed: () => context.go('/comandas'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Comandas'),
          ),
          if (c.aberta) ...[
            OutlinedButton.icon(
              onPressed: () async {
                final alterada =
                    await showDialog<Comanda>(context: context, builder: (_) => DialogoComanda(comanda: c));
                if (alterada != null) setState(() => _atual = alterada);
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar'),
            ),
            OutlinedButton.icon(
              onPressed: _ocupado ? null : () => _cancelar(c),
              style: OutlinedButton.styleFrom(foregroundColor: AppCores.perigo),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancelar comanda'),
            ),
          ],
        ],
      ),
      if (c.observacao != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('Obs.: ${c.observacao}', style: TextStyle(color: Colors.grey.shade700)),
        ),
      LayoutBuilder(builder: (context, k) {
        if (catalogo == null) return itens;
        if (k.maxWidth >= 900) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: catalogo),
            const SizedBox(width: 16),
            SizedBox(width: 380, child: itens),
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          itens,
          const SizedBox(height: 12),
          catalogo,
        ]);
      }),
    ]);
  }
}

// =============================================================================
// Itens da conta
// =============================================================================

class _PainelItens extends StatelessWidget {
  const _PainelItens({
    required this.comanda,
    required this.ocupado,
    required this.aoMais,
    required this.aoMenos,
    required this.aoRemover,
    required this.aoFechar,
  });

  final Comanda comanda;
  final bool ocupado;
  final ValueChanged<ItemComanda> aoMais;
  final ValueChanged<ItemComanda> aoMenos;
  final ValueChanged<ItemComanda> aoRemover;
  final VoidCallback aoFechar;

  @override
  Widget build(BuildContext context) {
    final c = comanda;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.receipt_long, color: AppCores.ambarEscuro),
            const SizedBox(width: 8),
            Text('Consumo', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            if (ocupado) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
          const Divider(height: 20),
          if (c.itens.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                c.aberta ? 'Nenhum item ainda. Toque nos produtos ou leia o código para lançar.' : 'Sem itens.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          for (final i in c.itens)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${formatarQuantidade(i.quantidade)}× ${i.produtoNome}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (i.observacao != null)
                      Text(i.observacao!,
                          style: const TextStyle(color: AppCores.ambarEscuro, fontSize: 12, fontStyle: FontStyle.italic)),
                    Text('${formatarMoeda(i.precoUnitario)} cada · ${formatarMoeda(i.total)}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ]),
                ),
                if (c.aberta) ...[
                  IconButton(
                    tooltip: 'Tirar 1',
                    visualDensity: VisualDensity.compact,
                    onPressed: ocupado ? null : () => aoMenos(i),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  IconButton(
                    tooltip: 'Mais 1',
                    visualDensity: VisualDensity.compact,
                    onPressed: ocupado ? null : () => aoMais(i),
                    icon: const Icon(Icons.add_circle_outline, color: AppCores.sucesso),
                  ),
                  IconButton(
                    tooltip: 'Remover item',
                    visualDensity: VisualDensity.compact,
                    onPressed: ocupado ? null : () => aoRemover(i),
                    icon: const Icon(Icons.delete_outline, color: AppCores.perigo),
                  ),
                ],
              ]),
            ),
          const Divider(height: 20),
          Row(children: [
            const Expanded(child: Text('Total', style: TextStyle(fontSize: 16))),
            Text(formatarMoeda(c.total), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          ]),
          if (c.aberta) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: ocupado || c.itens.isEmpty ? null : aoFechar,
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Fechar conta'),
            ),
          ],
          if (c.status == StatusComanda.cancelada && c.motivoCancelamento != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Cancelada: ${c.motivoCancelamento}', style: const TextStyle(color: AppCores.perigo)),
            ),
        ]),
      ),
    );
  }
}

// =============================================================================
// Catálogo para lançar
// =============================================================================

typedef _AoLancar = Future<void> Function(ItemCatalogo p, {num quantidade, String? observacao});

class _Catalogo extends ConsumerStatefulWidget {
  const _Catalogo({required this.aoLancar});

  final _AoLancar aoLancar;

  @override
  ConsumerState<_Catalogo> createState() => _CatalogoState();
}

class _CatalogoState extends ConsumerState<_Catalogo> {
  final _busca = TextEditingController();
  final _foco = FocusNode();
  String? _categoria;

  @override
  void dispose() {
    _busca.dispose();
    _foco.dispose();
    super.dispose();
  }

  List<ItemCatalogo> _filtrar(List<ItemCatalogo> todos) {
    final termo = _busca.text.trim().toLowerCase();
    return todos.where((p) {
      if (_categoria != null && p.categoriaId != _categoria) return false;
      if (termo.isEmpty) return true;
      return p.nome.toLowerCase().contains(termo) || (p.codigoInterno?.toLowerCase() == termo);
    }).toList();
  }

  /// Enter na busca: código exato (leitor USB) ou único resultado é lançado.
  Future<void> _enter(List<ItemCatalogo> todos) async {
    final termo = _busca.text.trim();
    if (termo.isEmpty) return;
    final porCodigo =
        todos.where((p) => p.codigoInterno != null && p.codigoInterno!.toLowerCase() == termo.toLowerCase());
    final filtrados = _filtrar(todos);
    final escolhido = porCodigo.isNotEmpty ? porCodigo.first : (filtrados.length == 1 ? filtrados.first : null);
    if (escolhido == null) {
      mostrarErro(context, 'Nenhum produto com o código "$termo".');
    } else {
      _busca.clear();
      setState(() {});
      await widget.aoLancar(escolhido);
    }
    _foco.requestFocus();
  }

  /// Toque longo: escolher quantidade e observação.
  Future<void> _lancarDetalhado(ItemCatalogo p) async {
    final qtd = TextEditingController(text: '1');
    final obs = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(p.nome),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: qtd,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Quantidade', suffixText: p.unidadeSigla),
            ),
            TextField(
              controller: obs,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Observação (opcional)', hintText: 'Ex.: sem gelo'),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Lançar')),
        ],
      ),
    );
    final quantidade = lerDecimal(qtd.text);
    final observacao = obs.text.trim().isEmpty ? null : obs.text.trim();
    qtd.dispose();
    obs.dispose();
    if (ok != true) return;
    if (quantidade == null || quantidade <= 0) {
      if (mounted) mostrarErro(context, 'Quantidade inválida.');
      return;
    }
    await widget.aoLancar(p, quantidade: quantidade, observacao: observacao);
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = ref.watch(catalogoPdvProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: catalogo.when(
          loading: () => const Carregando(),
          error: (e, _) => ErroView(mensagem: mensagemDeErro(e), aoTentarNovamente: () => ref.invalidate(catalogoPdvProvider)),
          data: (todos) {
            final categorias = <String, String>{
              for (final p in todos)
                if (p.categoriaId != null) p.categoriaId!: p.categoria ?? '',
            };
            final produtos = _filtrar(todos);
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(
                controller: _busca,
                focusNode: _foco,
                autofocus: !ehCelular(context),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Buscar produto ou ler código (Enter lança)',
                  suffixIcon: _busca.text.isEmpty
                      ? null
                      : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(_busca.clear)),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _enter(todos),
              ),
              const SizedBox(height: 10),
              RolavelNoCelular(
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  ChoiceChip(
                    label: const Text('Todos'),
                    selected: _categoria == null,
                    onSelected: (_) => setState(() => _categoria = null),
                  ),
                  for (final cat in categorias.entries)
                    ChoiceChip(
                      label: Text(cat.value),
                      selected: _categoria == cat.key,
                      onSelected: (_) => setState(() => _categoria = cat.key),
                    ),
                ]),
              ),
              const SizedBox(height: 12),
              Text('Toque para lançar 1 · toque longo para quantidade e observação',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              const SizedBox(height: 8),
              if (produtos.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Nenhum produto encontrado.',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
                )
              else
                GradeResponsiva(
                  larguraItem: 170,
                  espaco: 10,
                  children: [
                    for (final p in produtos)
                      _TileProduto(
                        produto: p,
                        aoTocar: () => widget.aoLancar(p),
                        aoTocarLongo: () => _lancarDetalhado(p),
                      ),
                  ],
                ),
            ]);
          },
        ),
      ),
    );
  }
}

class _TileProduto extends StatelessWidget {
  const _TileProduto({required this.produto, required this.aoTocar, required this.aoTocarLongo});

  final ItemCatalogo produto;
  final VoidCallback aoTocar;
  final VoidCallback aoTocarLongo;

  @override
  Widget build(BuildContext context) {
    final p = produto;
    return Opacity(
      opacity: p.esgotado ? 0.45 : 1,
      child: Material(
        color: AppCores.fundo,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: p.esgotado ? null : aoTocar,
          onLongPress: p.esgotado ? null : aoTocarLongo,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.nome, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(p.esgotado ? 'sem estoque' : formatarMoeda(p.precoVenda),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: p.esgotado ? AppCores.perigo : AppCores.ambarEscuro,
                  )),
            ]),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Fechar a conta
// =============================================================================

class _FecharContaDialog extends ConsumerStatefulWidget {
  const _FecharContaDialog({required this.comanda});

  final Comanda comanda;

  @override
  ConsumerState<_FecharContaDialog> createState() => _FecharContaDialogState();
}

class _FecharContaDialogState extends ConsumerState<_FecharContaDialog> {
  FormaPagamento _forma = FormaPagamento.pix;
  final _recebido = TextEditingController();
  final _desconto = TextEditingController();
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _recebido.dispose();
    _desconto.dispose();
    super.dispose();
  }

  num get _total {
    final t = widget.comanda.total - (lerDecimal(_desconto.text) ?? 0);
    return t < 0 ? 0 : t;
  }

  num? get _troco {
    if (_forma != FormaPagamento.dinheiro) return null;
    final r = lerDecimal(_recebido.text);
    return r == null ? null : r - _total;
  }

  Future<void> _confirmar() async {
    final troco = _troco;
    if (troco != null && troco < 0) {
      setState(() => _erro = 'O valor recebido é menor que o total.');
      return;
    }
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      final desconto = lerDecimal(_desconto.text);
      final c = await ref.read(comandasRepositoryProvider).fechar(
            widget.comanda.id,
            _forma,
            valorRecebido: _forma == FormaPagamento.dinheiro ? lerDecimal(_recebido.text) : null,
            desconto: desconto == null || desconto == 0 ? null : desconto,
          );
      if (mounted) Navigator.pop(context, c);
    } catch (e) {
      setState(() => _erro = mensagemDeErro(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comanda;
    final troco = _troco;
    return AlertDialog(
      title: Text('Fechar conta · comanda nº ${c.numero}'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${c.clienteNome}${c.local == null ? '' : ' · ${c.local}'}', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Text(formatarMoeda(_total),
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final f in FormaPagamento.values)
                ChoiceChip(
                  avatar: Icon(f.icone, size: 18),
                  label: Text(f.rotulo),
                  selected: _forma == f,
                  onSelected: (_) => setState(() => _forma = f),
                ),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: _desconto,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Desconto (opcional)', prefixText: r'R$ '),
              onChanged: (_) => setState(() {}),
            ),
            if (_forma == FormaPagamento.dinheiro) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _recebido,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Valor recebido', prefixText: r'R$ '),
                onChanged: (_) => setState(() {}),
              ),
              if (troco != null) ...[
                const SizedBox(height: 8),
                Text(
                  troco < 0 ? 'Falta ${formatarMoeda(-troco)}' : 'Troco ${formatarMoeda(troco)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: troco < 0 ? AppCores.perigo : AppCores.ambarEscuro,
                  ),
                ),
              ],
            ],
            if (_erro != null) ...[
              const SizedBox(height: 12),
              Text(_erro!, style: const TextStyle(color: AppCores.perigo)),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Voltar')),
        FilledButton.icon(
          onPressed: _enviando ? null : _confirmar,
          icon: const Icon(Icons.check),
          label: const Text('Concluir venda'),
        ),
      ],
    );
  }
}
