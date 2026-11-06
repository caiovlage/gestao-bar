import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../caixa/caixa.dart';
import '../caixa/caixa_dialogos.dart';
import '../estoque/estoque.dart';
import '../produtos/produtos.dart';
import 'venda_detalhe.dart';
import 'vendas.dart';

/// Tela de vendas (PDV): rápida, em tela cheia, separada do painel administrativo.
class PdvPage extends ConsumerWidget {
  const PdvPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caixa = ref.watch(caixaAtualProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDV'),
        leading: IconButton(
          tooltip: 'Voltar ao painel',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/vendas'),
        ),
        actions: [
          if (caixa.value != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  'Caixa aberto · ${caixa.value!.totais.quantidadeVendas} venda(s) · '
                  '${formatarMoeda(caixa.value!.totais.totalVendas)}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
        ],
      ),
      body: caixa.when(
        loading: () => const Carregando(),
        error: (e, _) => ErroView(mensagem: mensagemDeErro(e), aoTentarNovamente: () => ref.invalidate(caixaAtualProvider)),
        data: (c) => c == null
            ? EstadoVazio(
                icone: Icons.lock_outline,
                titulo: 'Caixa fechado',
                descricao: 'Abra o caixa para registrar vendas.',
                acao: FilledButton.icon(
                  onPressed: () => abrirCaixa(context, ref),
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Abrir caixa'),
                ),
              )
            : const _Pdv(),
      ),
    );
  }
}

class _Pdv extends ConsumerWidget {
  const _Pdv();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 900) {
        return Row(children: [
          const Expanded(child: _Catalogo()),
          Container(width: 1, color: Colors.grey.shade300),
          const SizedBox(width: 400, child: _PainelCarrinho()),
        ]);
      }
      return Column(children: [
        const Expanded(child: _Catalogo()),
        _BarraCarrinho(aoAbrir: () => _abrirCarrinho(context)),
      ]);
    });
  }

  void _abrirCarrinho(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.88,
        child: const _PainelCarrinho(),
      ),
    );
  }
}

// =============================================================================
// Catálogo
// =============================================================================

class _Catalogo extends ConsumerStatefulWidget {
  const _Catalogo();

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

  /// Enter na busca: código exato (leitor USB) ou único resultado entra no carrinho.
  void _enter(List<ItemCatalogo> todos) {
    final termo = _busca.text.trim();
    if (termo.isEmpty) return;
    final porCodigo = todos.where((p) => p.codigoInterno != null && p.codigoInterno!.toLowerCase() == termo.toLowerCase());
    final filtrados = _filtrar(todos);
    final escolhido = porCodigo.isNotEmpty ? porCodigo.first : (filtrados.length == 1 ? filtrados.first : null);
    if (escolhido == null) {
      mostrarErro(context, 'Nenhum produto com o código "$termo".');
    } else {
      _adicionar(escolhido);
      _busca.clear();
      setState(() {});
    }
    _foco.requestFocus();
  }

  void _adicionar(ItemCatalogo p) {
    if (p.esgotado) {
      mostrarErro(context, '${p.nome} está sem estoque.');
      return;
    }
    ref.read(carrinhoProvider.notifier).adicionar(p);
  }

  List<ItemCatalogo> _filtrar(List<ItemCatalogo> todos) {
    final termo = _busca.text.trim().toLowerCase();
    return todos.where((p) {
      if (_categoria != null && p.categoriaId != _categoria) return false;
      if (termo.isEmpty) return true;
      return p.nome.toLowerCase().contains(termo) || (p.codigoInterno?.toLowerCase() == termo);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = ref.watch(catalogoPdvProvider);
    return catalogo.when(
      loading: () => const Carregando(),
      error: (e, _) => ErroView(mensagem: mensagemDeErro(e), aoTentarNovamente: () => ref.invalidate(catalogoPdvProvider)),
      data: (todos) {
        final categorias = <String, String>{
          for (final p in todos)
            if (p.categoriaId != null) p.categoriaId!: p.categoria ?? '',
        };
        final produtos = _filtrar(todos);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _busca,
              focusNode: _foco,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Buscar produto ou ler código (Enter adiciona)',
                suffixIcon: _busca.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(_busca.clear),
                      ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _enter(todos),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Todos'),
                    selected: _categoria == null,
                    onSelected: (_) => setState(() => _categoria = null),
                  ),
                ),
                for (final c in categorias.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c.value),
                      selected: _categoria == c.key,
                      onSelected: (_) => setState(() => _categoria = c.key),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: produtos.isEmpty
                ? const EstadoVazio(
                    icone: Icons.search_off,
                    titulo: 'Nenhum produto',
                    descricao: 'Produtos aparecem aqui quando estão ativos, à venda e com preço.',
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 180,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: produtos.length,
                    itemBuilder: (_, i) => _CartaoProduto(produto: produtos[i], aoTocar: () => _adicionar(produtos[i])),
                  ),
          ),
        ]);
      },
    );
  }
}

class _CartaoProduto extends ConsumerWidget {
  const _CartaoProduto({required this.produto, required this.aoTocar});

  final ItemCatalogo produto;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = produto;
    final url = ref.read(vendasRepositoryProvider).urlImagem(p.imagemUrl);
    final quantidade = ref.watch(carrinhoProvider.select(
        (c) => c.itens.where((i) => i.produto.produtoId == p.produtoId).fold<int>(0, (s, i) => s + i.quantidade)));
    final semImagem = Container(
      color: AppCores.fundo,
      child: Icon(Icons.local_bar, size: 40, color: Colors.grey.shade400),
    );
    return Opacity(
      opacity: p.esgotado ? 0.45 : 1,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: aoTocar,
          child: Stack(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: url == null ? semImagem : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => semImagem),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.nome, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, height: 1.2)),
                  const SizedBox(height: 4),
                  Text(formatarMoeda(p.precoVenda),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppCores.ambarEscuro)),
                  if (p.esgotado) const Text('sem estoque', style: TextStyle(fontSize: 11, color: AppCores.perigo)),
                ]),
              ),
            ]),
            if (quantidade > 0)
              Positioned(
                top: 6,
                right: 6,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: AppCores.ambar,
                  child: Text('$quantidade',
                      style: const TextStyle(color: AppCores.sobreAmbar, fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

// =============================================================================
// Carrinho
// =============================================================================

class _BarraCarrinho extends ConsumerWidget {
  const _BarraCarrinho({required this.aoAbrir});

  final VoidCallback aoAbrir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(carrinhoProvider);
    return Material(
      color: AppCores.grafite,
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: aoAbrir,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(children: [
              const Icon(Icons.shopping_cart, color: Colors.white),
              const SizedBox(width: 10),
              Text('${c.quantidadeItens} item(ns)', style: const TextStyle(color: Colors.white)),
              const Spacer(),
              Text(formatarMoeda(c.total),
                  style: const TextStyle(color: AppCores.ambar, fontWeight: FontWeight.w800, fontSize: 20)),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_up, color: Colors.white),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PainelCarrinho extends ConsumerStatefulWidget {
  const _PainelCarrinho();

  @override
  ConsumerState<_PainelCarrinho> createState() => _PainelCarrinhoState();
}

class _PainelCarrinhoState extends ConsumerState<_PainelCarrinho> {
  late final _desconto = TextEditingController(text: formatarParaEdicao(ref.read(carrinhoProvider).descontoInformado));
  late final _recebido = TextEditingController(text: formatarParaEdicao(ref.read(carrinhoProvider).valorRecebido));
  bool _enviando = false;

  @override
  void dispose() {
    _desconto.dispose();
    _recebido.dispose();
    super.dispose();
  }

  Future<void> _finalizar() async {
    final carrinho = ref.read(carrinhoProvider);
    if (carrinho.vazio || _enviando) return;
    if (carrinho.troco != null && carrinho.troco! < 0) {
      mostrarErro(context, 'O valor recebido é menor que o total.');
      return;
    }
    setState(() => _enviando = true);
    try {
      final venda = await ref.read(vendasRepositoryProvider).registrar(carrinho);
      ref.read(carrinhoProvider.notifier).limpar();
      _desconto.clear();
      _recebido.clear();
      ref.invalidate(caixaAtualProvider);
      ref.invalidate(catalogoPdvProvider);
      ref.invalidate(vendasProvider);
      ref.invalidate(posicaoEstoqueProvider);
      ref.invalidate(produtosPaginaProvider);
      if (mounted) await _vendaConcluida(venda);
    } catch (e) {
      // A chave do carrinho é mantida: tentar de novo não duplica a venda se a primeira tiver sido gravada.
      if (mounted) mostrarErro(context, e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _vendaConcluida(Venda v) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: AppCores.sucesso, size: 48),
        title: Text('Venda nº ${v.numero} registrada'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(formatarMoeda(v.total), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
          Text(v.formaPagamento.rotulo),
          if (v.troco != null && v.troco! > 0) ...[
            const SizedBox(height: 12),
            Text('Troco: ${formatarMoeda(v.troco)}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppCores.ambarEscuro)),
          ],
        ]),
        actions: [
          TextButton.icon(
            onPressed: () => mostrarComprovante(context, v),
            icon: const Icon(Icons.receipt_long),
            label: const Text('Comprovante'),
          ),
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Nova venda'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(carrinhoProvider);
    final controle = ref.read(carrinhoProvider.notifier);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
        child: Row(children: [
          Text('Carrinho', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          if (!c.vazio)
            TextButton.icon(
              onPressed: () async {
                if (await confirmar(context, titulo: 'Limpar carrinho', mensagem: 'Remover todos os itens?', acao: 'Limpar')) {
                  controle.limpar();
                  _desconto.clear();
                  _recebido.clear();
                }
              },
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Limpar'),
            ),
        ]),
      ),
      Expanded(
        child: c.vazio
            ? Center(
                child: Text('Toque nos produtos para adicionar.', style: TextStyle(color: Colors.grey.shade600)),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: c.itens.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (_, i) {
                  final item = c.itens[i];
                  return Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.produto.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(formatarMoeda(item.produto.precoVenda),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ]),
                    ),
                    IconButton(
                      tooltip: 'Menos',
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => controle.alterarQuantidade(item.produto.produtoId, -1),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text('${item.quantidade}',
                          textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                    IconButton(
                      tooltip: 'Mais',
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => controle.alterarQuantidade(item.produto.produtoId, 1),
                    ),
                    SizedBox(
                      width: 84,
                      child: Text(formatarMoeda(item.total),
                          textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ]);
                },
              ),
      ),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _desconto,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Desconto',
                  isDense: true,
                  prefixText: c.descontoPercentual ? null : r'R$ ',
                  suffixText: c.descontoPercentual ? '%' : null,
                ),
                onChanged: (t) => controle.desconto(lerDecimal(t), percentual: c.descontoPercentual),
              ),
            ),
            const SizedBox(width: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text(r'R$')),
                ButtonSegment(value: true, label: Text('%')),
              ],
              selected: {c.descontoPercentual},
              onSelectionChanged: (s) => controle.desconto(lerDecimal(_desconto.text), percentual: s.first),
            ),
          ]),
          const SizedBox(height: 12),
          _Total('Subtotal', formatarMoeda(c.subtotal)),
          if (c.desconto > 0) _Total('Desconto', '−${formatarMoeda(c.desconto)}'),
          _Total('Total', formatarMoeda(c.total), destaque: true),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final f in FormaPagamento.values)
              ChoiceChip(
                avatar: Icon(f.icone, size: 18),
                label: Text(f.rotulo),
                selected: c.forma == f,
                onSelected: (_) => controle.forma(f),
              ),
          ]),
          if (c.forma == FormaPagamento.dinheiro) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _recebido,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Valor recebido', prefixText: r'R$ ', isDense: true),
                  onChanged: (t) => controle.valorRecebido(lerDecimal(t)),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                c.troco == null ? '' : (c.troco! < 0 ? 'Falta ${formatarMoeda(-c.troco!)}' : 'Troco ${formatarMoeda(c.troco)}'),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: (c.troco ?? 0) < 0 ? AppCores.perigo : AppCores.ambarEscuro,
                ),
              ),
            ]),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            onPressed: c.vazio || _enviando ? null : _finalizar,
            icon: _enviando
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Icon(Icons.check),
            label: Text('Finalizar ${formatarMoeda(c.total)}'),
          ),
        ]),
      ),
    ]);
  }
}

class _Total extends StatelessWidget {
  const _Total(this.rotulo, this.valor, {this.destaque = false});

  final String rotulo;
  final String valor;
  final bool destaque;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(rotulo, style: TextStyle(fontSize: destaque ? 18 : 14, fontWeight: destaque ? FontWeight.w700 : null))),
          Text(valor, style: TextStyle(fontSize: destaque ? 24 : 14, fontWeight: FontWeight.w800)),
        ]),
      );
}
