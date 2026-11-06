import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/widgets/download/download.dart';
import '../estoque/estoque.dart';
import '../fornecedores/fornecedores.dart';
import '../produtos/produtos.dart';
import '../unidades/unidades.dart';
import 'compras.dart';

/// Lista de compras: edição (rascunho), exportação e recebimento.
class CompraPage extends ConsumerWidget {
  const CompraPage({super.key, this.compraId});

  final String? compraId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Compra?> compra =
        compraId == null ? const AsyncData<Compra?>(null) : ref.watch(compraProvider(compraId!));
    final produtos = ref.watch(produtosCompraveisProvider);
    final unidades = ref.watch(unidadesProvider);
    final fornecedores = ref.watch(fornecedoresAtivosProvider);
    final todos = <AsyncValue<Object?>>[compra, produtos, unidades, fornecedores];
    final erro = todos.where((a) => a.hasError).firstOrNull;
    if (erro != null) return ErroView(mensagem: mensagemDeErro(erro.error!));
    if (todos.any((a) => !a.hasValue)) return const Carregando();
    return _Formulario(
      key: ValueKey('${compra.value?.id}-${compra.value?.status.api}'),
      compra: compra.value,
      produtos: produtos.value!,
      unidades: unidades.value!,
      fornecedores: fornecedores.value!,
    );
  }
}

class _Linha {
  _Linha({this.produtoId, this.opcao, String quantidade = '', String custo = ''})
      : quantidade = TextEditingController(text: quantidade),
        custo = TextEditingController(text: custo);

  String? produtoId;

  /// 'e:<embalagemId>' ou 'u:<unidadeId>'.
  String? opcao;
  final TextEditingController quantidade;
  final TextEditingController custo;

  void dispose() {
    quantidade.dispose();
    custo.dispose();
  }
}

class _Formulario extends ConsumerStatefulWidget {
  const _Formulario({super.key, required this.compra, required this.produtos, required this.unidades, required this.fornecedores});

  final Compra? compra;
  final List<ProdutoCompravel> produtos;
  final List<UnidadeMedida> unidades;
  final List<Fornecedor> fornecedores;

  @override
  ConsumerState<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends ConsumerState<_Formulario> {
  late final Map<String, ProdutoCompravel> _porId = {for (final p in widget.produtos) p.id: p};
  late String? _fornecedorId = widget.compra?.fornecedorId;
  late final _obs = TextEditingController(text: widget.compra?.observacao);
  late final List<_Linha> _linhas = [
    for (final i in widget.compra?.itens ?? const <ItemCompra>[])
      _Linha(
        produtoId: i.produtoId,
        opcao: i.embalagemId != null ? 'e:${i.embalagemId}' : 'u:${i.unidadeId ?? _porId[i.produtoId]?.unidadeId}',
        quantidade: formatarParaEdicao(i.quantidade),
        custo: formatarParaEdicao(i.custoUnitario),
      ),
  ];
  bool _ocupado = false;

  Compra? get _c => widget.compra;
  bool get _editavel => _c == null || _c!.editavel;

  @override
  void dispose() {
    _obs.dispose();
    for (final l in _linhas) {
      l.dispose();
    }
    super.dispose();
  }

  List<(String, String)> _opcoes(ProdutoCompravel p) => [
        for (final e in p.embalagens) ('e:${e.id}', '${e.descricao} (${formatarQuantidade(e.fator)} ${p.unidadeSigla})'),
        ('u:${p.unidadeId}', p.unidadeSigla),
        for (final u in widget.unidades)
          if (!u.embalagem && u.grandeza == p.grandeza && u.id != p.unidadeId) ('u:${u.id}', u.sigla),
      ];

  /// Preço sugerido pela unidade escolhida, a partir do custo atual do produto.
  num _custoSugerido(ProdutoCompravel p, String opcao) {
    if (opcao.startsWith('e:')) {
      final e = p.embalagens.where((x) => 'e:${x.id}' == opcao).firstOrNull;
      return p.custoMedio * (e?.fator ?? 1);
    }
    final u = widget.unidades.where((x) => 'u:${x.id}' == opcao).firstOrNull;
    return p.custoMedio * (u?.fatorBase ?? 1);
  }

  List<ItemCompraForm>? _itens() {
    final itens = <ItemCompraForm>[];
    for (final (i, l) in _linhas.indexed) {
      final qtd = lerDecimal(l.quantidade.text);
      final custo = lerDecimal(l.custo.text);
      if (l.produtoId == null || l.opcao == null || qtd == null || qtd <= 0 || custo == null || custo < 0) {
        mostrarErro(context, 'Complete a linha ${i + 1}: produto, quantidade e preço.');
        return null;
      }
      itens.add((
        produtoId: l.produtoId!,
        quantidade: qtd,
        unidadeId: l.opcao!.startsWith('u:') ? l.opcao!.substring(2) : null,
        embalagemId: l.opcao!.startsWith('e:') ? l.opcao!.substring(2) : null,
        custoUnitario: custo,
      ));
    }
    return itens;
  }

  Future<Compra?> _salvar({bool avisar = true}) async {
    final itens = _itens();
    if (itens == null) return null;
    setState(() => _ocupado = true);
    try {
      final salva = await ref.read(comprasRepositoryProvider).salvar(_c?.id,
          fornecedorId: _fornecedorId, observacao: _obs.text.trim().isEmpty ? null : _obs.text.trim(), itens: itens);
      ref.invalidate(comprasProvider);
      if (_c == null) {
        if (mounted) context.go('/compras/${salva.id}');
      } else {
        ref.invalidate(compraProvider(salva.id));
      }
      if (avisar && mounted) mostrarSucesso(context, 'Lista salva.');
      return salva;
    } catch (e) {
      if (mounted) mostrarErro(context, e);
      return null;
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _receber() async {
    final salva = await _salvar(avisar: false);
    if (salva == null || !mounted) return;
    final ok = await confirmar(context,
        titulo: 'Registrar recebimento',
        mensagem: 'Os ${salva.itens.length} item(ns) entram no estoque e o custo médio dos produtos é recalculado '
            'com os preços desta compra (${formatarMoeda(salva.total)}). Depois disso a lista não pode ser alterada.',
        acao: 'Registrar recebimento');
    if (!ok) return;
    try {
      await ref.read(comprasRepositoryProvider).receber(salva.id);
      ref.invalidate(compraProvider(salva.id));
      ref.invalidate(comprasProvider);
      ref.invalidate(sugestoesCompraProvider);
      ref.invalidate(produtosCompraveisProvider);
      ref.invalidate(posicaoEstoqueProvider);
      ref.invalidate(resumoEstoqueProvider);
      ref.invalidate(produtosPaginaProvider);
      if (mounted) mostrarSucesso(context, 'Compra recebida: estoque e custos atualizados.');
    } catch (e) {
      if (mounted) mostrarErro(context, e);
    }
  }

  Future<void> _cancelar() async {
    if (!await confirmar(context, titulo: 'Cancelar lista', mensagem: 'Cancelar esta lista de compras?', acao: 'Cancelar lista', perigoso: true)) {
      return;
    }
    try {
      await ref.read(comprasRepositoryProvider).cancelar(_c!.id);
      ref.invalidate(compraProvider(_c!.id));
      ref.invalidate(comprasProvider);
    } catch (e) {
      if (mounted) mostrarErro(context, e);
    }
  }

  Future<void> _exportar(String formato) async {
    final c = _c;
    if (c == null) return;
    if (_editavel && await _salvar(avisar: false) == null) return;
    try {
      final bytes = await ref.read(comprasRepositoryProvider).exportar(c.id, formato);
      final pdf = formato == 'pdf';
      final ok = await baixarArquivo(bytes, 'lista-de-compras-${c.numero}.${pdf ? 'pdf' : 'xlsx'}',
          pdf ? 'application/pdf' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      if (!ok && mounted) mostrarErro(context, 'Exportação disponível no navegador.');
    } catch (e) {
      if (mounted) mostrarErro(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    num total = 0;
    for (final l in _linhas) {
      total += (lerDecimal(l.quantidade.text) ?? 0) * (lerDecimal(l.custo.text) ?? 0);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CabecalhoPagina(
        titulo: c == null ? 'Nova lista de compras' : 'Lista de compras nº ${c.numero}',
        subtitulo: c == null
            ? null
            : [c.status.rotulo, 'criada em ${formatarDataHora(c.criadaEm)}',
                if (c.recebidaEm != null) 'recebida em ${formatarDataHora(c.recebidaEm)}'].join(' · '),
        acoes: [
          OutlinedButton.icon(onPressed: () => context.go('/compras'), icon: const Icon(Icons.arrow_back), label: const Text('Voltar')),
          if (c != null) ...[
            OutlinedButton.icon(onPressed: () => _exportar('pdf'), icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('PDF')),
            OutlinedButton.icon(onPressed: () => _exportar('xlsx'), icon: const Icon(Icons.table_view_outlined), label: const Text('Excel')),
          ],
          if (_editavel) ...[
            if (c != null)
              OutlinedButton(
                onPressed: _ocupado ? null : _cancelar,
                style: OutlinedButton.styleFrom(foregroundColor: AppCores.perigo),
                child: const Text('Cancelar lista'),
              ),
            OutlinedButton.icon(onPressed: _ocupado ? null : () => _salvar(), icon: const Icon(Icons.save_outlined), label: const Text('Salvar')),
            FilledButton.icon(
              onPressed: _ocupado || _linhas.isEmpty ? null : _receber,
              icon: const Icon(Icons.inventory),
              label: const Text('Registrar recebimento'),
            ),
          ],
        ],
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(spacing: 16, runSpacing: 12, children: [
            SizedBox(
              width: 320,
              child: DropdownButtonFormField<String?>(
                initialValue: widget.fornecedores.any((f) => f.id == _fornecedorId) ? _fornecedorId : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Fornecedor'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sem fornecedor')),
                  for (final f in widget.fornecedores) DropdownMenuItem(value: f.id, child: Text(f.nomeExibicao, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: _editavel ? (v) => setState(() => _fornecedorId = v) : null,
              ),
            ),
            SizedBox(
              width: 420,
              child: TextField(
                controller: _obs,
                enabled: _editavel,
                maxLength: 500,
                decoration: const InputDecoration(labelText: 'Observação', counterText: ''),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_linhas.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Nenhum item. Adicione produtos ou gere a lista pelas sugestões.',
                    style: TextStyle(color: Colors.grey.shade600)),
              ),
            for (final (i, l) in _linhas.indexed) _linha(i, l),
            if (_editavel)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _linhas.add(_Linha())),
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar produto'),
                ),
              ),
            const Divider(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: Text('Total ${formatarMoeda(c != null && !_editavel ? c.total : total)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            if (c != null && !_editavel)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  c.itens.map((i) => '${i.produtoNome}: +${formatarQuantidade(i.quantidadeEstoque)} ${i.unidadeEstoque}').join(' · '),
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
          ]),
        ),
      ),
    ]);
  }

  Widget _linha(int indice, _Linha l) {
    final produto = _porId[l.produtoId];
    final opcoes = produto == null ? const <(String, String)>[] : _opcoes(produto);
    final nomeFora = widget.compra?.itens.where((i) => i.produtoId == l.produtoId).firstOrNull?.produtoNome;
    return Padding(
      key: ObjectKey(l),
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 5,
          child: DropdownMenu<String>(
            initialSelection: l.produtoId,
            enabled: _editavel,
            expandedInsets: EdgeInsets.zero,
            enableFilter: true,
            requestFocusOnTap: true,
            menuHeight: 320,
            hintText: 'Produto (digite para buscar)',
            dropdownMenuEntries: [
              for (final p in widget.produtos) DropdownMenuEntry(value: p.id, label: p.nome),
              if (l.produtoId != null && produto == null && nomeFora != null) DropdownMenuEntry(value: l.produtoId!, label: nomeFora),
            ],
            onSelected: (id) => setState(() {
              l.produtoId = id;
              final p = _porId[id];
              if (p != null) {
                l.opcao = _opcoes(p).first.$1;
                l.custo.text = formatarParaEdicao(_custoSugerido(p, l.opcao!));
                if (l.quantidade.text.isEmpty) l.quantidade.text = '1';
              }
            }),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: TextField(
            controller: l.quantidade,
            enabled: _editavel,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Qtd.'),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<String>(
            key: ValueKey('${l.produtoId}-${l.opcao}'),
            initialValue: opcoes.any((o) => o.$1 == l.opcao) ? l.opcao : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Unidade'),
            items: [for (final o in opcoes) DropdownMenuItem(value: o.$1, child: Text(o.$2, overflow: TextOverflow.ellipsis))],
            onChanged: !_editavel
                ? null
                : (v) => setState(() {
                      l.opcao = v;
                      if (produto != null && v != null) l.custo.text = formatarParaEdicao(_custoSugerido(produto, v));
                    }),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: TextField(
            controller: l.custo,
            enabled: _editavel,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Preço unit.', prefixText: r'R$ '),
            onChanged: (_) => setState(() {}),
          ),
        ),
        if (_editavel)
          IconButton(
            tooltip: 'Remover',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(() => _linhas.removeAt(indice).dispose()),
          ),
      ]),
    );
  }
}
