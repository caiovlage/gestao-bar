import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/widgets/leitor_codigo.dart';
import '../../app/widgets/paginacao.dart';
import '../categorias/categorias.dart';
import 'produto_imagem.dart';
import 'produtos.dart';

class ProdutosPage extends ConsumerStatefulWidget {
  const ProdutosPage({super.key});

  @override
  ConsumerState<ProdutosPage> createState() => _ProdutosPageState();
}

class _ProdutosPageState extends ConsumerState<ProdutosPage> {
  late final _busca = TextEditingController(text: ref.read(filtroProdutosProvider).nome);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _busca.dispose();
    super.dispose();
  }

  /// Código já cadastrado: abre o produto. Código novo: abre o cadastro com o código preenchido.
  Future<void> _lerCodigo() async {
    final codigo = await lerCodigo(context);
    if (codigo == null || !mounted) return;
    try {
      final produto = await ref.read(produtosRepositoryProvider).buscarPorCodigo(codigo);
      if (mounted) context.go('/produtos/${produto.id}');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 404) {
        mostrarSucesso(context, 'Código $codigo não cadastrado: preencha o novo produto.');
        context.go(Uri(path: '/produtos/novo', queryParameters: {'codigo': codigo}).toString());
      } else {
        mostrarErro(context, e);
      }
    }
  }

  void _aoDigitar(String texto) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => ref.read(filtroProdutosProvider.notifier).nome(texto.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtro = ref.watch(filtroProdutosProvider);
    final controle = ref.read(filtroProdutosProvider.notifier);
    final categorias = ref.watch(categoriasProvider).value ?? const <Categoria>[];
    final pagina = ref.watch(produtosPaginaProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CabecalhoPagina(
          titulo: 'Produtos',
          subtitulo: 'Itens de revenda, ingredientes e produtos preparados',
          acoes: [
            OutlinedButton.icon(
              onPressed: _lerCodigo,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Ler código'),
            ),
            FilledButton.icon(
              onPressed: () => context.go('/produtos/novo'),
              icon: const Icon(Icons.add),
              label: const Text('Novo produto'),
            ),
          ],
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: _busca,
                onChanged: _aoDigitar,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Nome ou código',
                ),
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String?>(
                // recria o campo quando as categorias terminam de carregar
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
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<TipoProduto?>(
                initialValue: filtro.tipo,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos')),
                  for (final t in TipoProduto.values) DropdownMenuItem(value: t, child: Text(t.rotulo)),
                ],
                onChanged: controle.tipo,
              ),
            ),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('Ativos')),
                ButtonSegment(value: 0, label: Text('Inativos')),
                ButtonSegment(value: 2, label: Text('Todos')),
              ],
              selected: {filtro.ativo == null ? 2 : (filtro.ativo! ? 1 : 0)},
              onSelectionChanged: (s) => controle.ativo(switch (s.first) { 1 => true, 0 => false, _ => null }),
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
              aoTentarNovamente: () => ref.invalidate(produtosPaginaProvider),
            ),
            data: (p) => p.conteudo.isEmpty
                ? EstadoVazio(
                    icone: Icons.inventory_2_outlined,
                    titulo: 'Nenhum produto encontrado',
                    descricao: 'Ajuste os filtros ou cadastre um novo produto.',
                    acao: OutlinedButton.icon(
                      onPressed: () => context.go('/produtos/novo'),
                      icon: const Icon(Icons.add),
                      label: const Text('Cadastrar produto'),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final largo = constraints.maxWidth >= 860;
                      return Column(
                        children: [
                          if (largo) const _CabecalhoTabela(),
                          for (final (i, produto) in p.conteudo.indexed) ...[
                            if (i > 0 || largo) const Divider(),
                            largo ? _LinhaProduto(produto: produto) : _CartaoProduto(produto: produto),
                          ],
                          const Divider(),
                          Paginacao(pagina: p, aoMudar: controle.pagina),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

const _estiloCabecalho = TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF6B7280));

class _CabecalhoTabela extends StatelessWidget {
  const _CabecalhoTabela();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(children: [
        SizedBox(width: 56),
        Expanded(flex: 4, child: Text('PRODUTO', style: _estiloCabecalho)),
        Expanded(flex: 2, child: Text('CATEGORIA', style: _estiloCabecalho)),
        Expanded(flex: 2, child: Text('ESTOQUE', style: _estiloCabecalho)),
        Expanded(flex: 2, child: Text('CUSTO', style: _estiloCabecalho, textAlign: TextAlign.right)),
        Expanded(flex: 2, child: Text('PREÇO', style: _estiloCabecalho, textAlign: TextAlign.right)),
        Expanded(flex: 2, child: Text('MARGEM', style: _estiloCabecalho, textAlign: TextAlign.right)),
        SizedBox(width: 90, child: Text('STATUS', style: _estiloCabecalho, textAlign: TextAlign.center)),
      ]),
    );
  }
}

class _LinhaProduto extends ConsumerWidget {
  const _LinhaProduto({required this.produto});

  final Produto produto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = produto;
    final url = ref.read(produtosRepositoryProvider).urlImagem(p.imagemUrl);
    return InkWell(
      onTap: () => context.go('/produtos/${p.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          ProdutoImagem(url: url, tamanho: 44),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                [p.tipo.rotulo, if (p.codigoInterno != null) 'Cód. ${p.codigoInterno}'].join(' · '),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ]),
          ),
          Expanded(flex: 2, child: Text(p.categoriaNome ?? '—')),
          Expanded(flex: 2, child: _Estoque(produto: p)),
          Expanded(
            flex: 2,
            child: Text(
              '${formatarMoeda(p.custoMedio)}/${p.unidadeEstoque.sigla}',
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(flex: 2, child: Text(formatarMoeda(p.precoVenda), textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text(formatarPercentual(p.margemBrutaPercentual), textAlign: TextAlign.right)),
          SizedBox(width: 90, child: Center(child: Etiqueta.status(p.ativo))),
        ]),
      ),
    );
  }
}

class _CartaoProduto extends ConsumerWidget {
  const _CartaoProduto({required this.produto});

  final Produto produto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = produto;
    final url = ref.read(produtosRepositoryProvider).urlImagem(p.imagemUrl);
    return ListTile(
      onTap: () => context.go('/produtos/${p.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: ProdutoImagem(url: url, tamanho: 48),
      title: Text(p.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(p.categoriaNome ?? p.tipo.rotulo),
          _Estoque(produto: p),
          if (!p.ativo) Etiqueta.status(false),
        ]),
      ),
      trailing: Text(
        p.tipo.vendavel ? formatarMoeda(p.precoVenda) : '',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Estoque extends StatelessWidget {
  const _Estoque({required this.produto});

  final Produto produto;

  @override
  Widget build(BuildContext context) {
    if (!produto.controlaEstoque) {
      return Tooltip(
        message: 'Sem controle de estoque (prato preparado)',
        child: Etiqueta('Sem estoque', cor: Colors.grey.shade600),
      );
    }
    final texto = '${formatarQuantidade(produto.estoqueAtual)} ${produto.unidadeEstoque.sigla}';
    if (!produto.abaixoMinimo) return Text(texto);
    return Tooltip(
      message: 'Abaixo do mínimo (${formatarQuantidade(produto.estoqueMinimo)} ${produto.unidadeEstoque.sigla})',
      child: Etiqueta(texto, cor: AppCores.perigo, icone: Icons.warning_amber_rounded),
    );
  }
}
