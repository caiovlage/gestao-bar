import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../categorias/categorias.dart';
import '../fornecedores/fornecedores.dart';
import '../unidades/unidades.dart';
import 'produto_imagem.dart';
import 'produtos.dart';

final _produtoDetalheProvider = FutureProvider.autoDispose.family<Produto, String>(
  (ref, id) => ref.watch(produtosRepositoryProvider).buscar(id),
);

/// Carrega os dados de apoio (unidades, categorias, fornecedores e o produto, se edição)
/// e então exibe o formulário.
class ProdutoFormPage extends ConsumerWidget {
  const ProdutoFormPage({super.key, this.produtoId});

  final String? produtoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unidades = ref.watch(unidadesProvider);
    final categorias = ref.watch(categoriasProvider);
    final fornecedores = ref.watch(fornecedoresAtivosProvider);
    final AsyncValue<Produto?> produto =
        produtoId == null ? const AsyncData<Produto?>(null) : ref.watch(_produtoDetalheProvider(produtoId!));

    final erro = [unidades, categorias, fornecedores, produto].where((a) => a.hasError).firstOrNull;
    if (erro != null) {
      return ErroView(
        mensagem: mensagemDeErro(erro.error!),
        aoTentarNovamente: () {
          ref.invalidate(unidadesProvider);
          ref.invalidate(categoriasProvider);
          ref.invalidate(fornecedoresAtivosProvider);
          if (produtoId != null) ref.invalidate(_produtoDetalheProvider(produtoId!));
        },
      );
    }
    if (!unidades.hasValue || !categorias.hasValue || !fornecedores.hasValue || !produto.hasValue) {
      return const Carregando();
    }
    return _ProdutoFormulario(
      key: ValueKey(produtoId),
      produto: produto.value,
      unidades: unidades.value!,
      categorias: categorias.value!,
      fornecedores: fornecedores.value!,
    );
  }
}

class _EmbalagemEdicao {
  _EmbalagemEdicao({this.id, this.unidadeId, String descricao = '', String fator = ''})
      : descricao = TextEditingController(text: descricao),
        fator = TextEditingController(text: fator);

  final String? id;
  String? unidadeId;
  final TextEditingController descricao;
  final TextEditingController fator;

  void dispose() {
    descricao.dispose();
    fator.dispose();
  }
}

class _ProdutoFormulario extends ConsumerStatefulWidget {
  const _ProdutoFormulario({
    super.key,
    required this.produto,
    required this.unidades,
    required this.categorias,
    required this.fornecedores,
  });

  final Produto? produto;
  final List<UnidadeMedida> unidades;
  final List<Categoria> categorias;
  final List<Fornecedor> fornecedores;

  @override
  ConsumerState<_ProdutoFormulario> createState() => _ProdutoFormularioState();
}

class _ProdutoFormularioState extends ConsumerState<_ProdutoFormulario> {
  final _form = GlobalKey<FormState>();

  late Produto? _produto = widget.produto;
  late final _nome = TextEditingController(text: _produto?.nome);
  late final _descricao = TextEditingController(text: _produto?.descricao);
  late final _custo = TextEditingController(text: formatarParaEdicao(_produto?.custoMedio));
  late final _preco = TextEditingController(text: formatarParaEdicao(_produto?.precoVenda));
  late final _estoqueMinimo = TextEditingController(text: formatarParaEdicao(_produto?.estoqueMinimo ?? 0));
  late final _codigo = TextEditingController(text: _produto?.codigoInterno);

  late String? _categoriaId = _produto?.categoriaId;
  late TipoProduto _tipo = _produto?.tipo ?? TipoProduto.revenda;
  late String? _unidadeId = _produto?.unidadeEstoque.id ??
      widget.unidades.where((u) => u.sigla == 'un').firstOrNull?.id;
  late String? _fornecedorId = _produto?.fornecedorPrincipalId;
  late bool _vendeNoCardapio = _produto?.vendeNoCardapio ?? true;
  late final List<_EmbalagemEdicao> _embalagens = [
    for (final e in _produto?.embalagens ?? const <Embalagem>[])
      _EmbalagemEdicao(
        id: e.id,
        unidadeId: e.unidade.id,
        descricao: e.descricao,
        fator: formatarParaEdicao(e.fator),
      ),
  ];

  Uint8List? _novaImagem;
  String? _nomeNovaImagem;
  bool _salvando = false;
  ApiException? _erro;

  bool get _edicao => _produto != null;

  List<UnidadeMedida> get _unidadesBase => widget.unidades.where((u) => u.unidadeBase).toList();
  List<UnidadeMedida> get _unidadesEmbalagem => widget.unidades.where((u) => u.embalagem).toList();

  UnidadeMedida? get _unidadeEstoque => widget.unidades.where((u) => u.id == _unidadeId).firstOrNull;

  @override
  void dispose() {
    for (final c in [_nome, _descricao, _custo, _preco, _estoqueMinimo, _codigo]) {
      c.dispose();
    }
    for (final e in _embalagens) {
      e.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------- ações

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    final repo = ref.read(produtosRepositoryProvider);
    try {
      final form = ProdutoForm(
        nome: _nome.text.trim(),
        descricao: _descricao.text.trim().isEmpty ? null : _descricao.text.trim(),
        categoriaId: _categoriaId,
        tipo: _tipo,
        unidadeEstoqueId: _unidadeId!,
        custoMedio: lerDecimal(_custo.text) ?? 0,
        precoVenda: _tipo.vendavel ? lerDecimal(_preco.text) : null,
        estoqueMinimo: lerDecimal(_estoqueMinimo.text) ?? 0,
        fornecedorPrincipalId: _fornecedorId,
        codigoInterno: _codigo.text.trim().isEmpty ? null : _codigo.text.trim(),
        vendeNoCardapio: _tipo.vendavel && _vendeNoCardapio,
        embalagens: [
          for (final e in _embalagens)
            (id: e.id, unidadeId: e.unidadeId!, descricao: e.descricao.text.trim(), fator: lerDecimal(e.fator.text)!),
        ],
      );
      var salvo = await repo.salvar(_produto?.id, form);

      if (_novaImagem != null) {
        try {
          salvo = await repo.enviarImagem(salvo.id, _novaImagem!, _nomeNovaImagem ?? 'imagem.jpg');
        } catch (e) {
          if (mounted) {
            mostrarErro(context, 'Produto salvo, mas a imagem não foi enviada: ${mensagemDeErro(e)}');
            context.go('/produtos/${salvo.id}');
          }
          return;
        }
      }

      ref.invalidate(produtosPaginaProvider);
      if (mounted) {
        mostrarSucesso(context, _edicao ? 'Produto atualizado.' : 'Produto cadastrado.');
        context.go('/produtos');
      }
    } on ApiException catch (e) {
      setState(() => _erro = e);
      if (mounted && e.campos.isEmpty) mostrarErro(context, e);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _escolherImagem() async {
    final arquivo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (arquivo == null) return;
    final bytes = await arquivo.readAsBytes();
    setState(() {
      _novaImagem = bytes;
      _nomeNovaImagem = arquivo.name;
    });
  }

  Future<void> _removerImagem() async {
    if (_novaImagem != null) {
      setState(() {
        _novaImagem = null;
        _nomeNovaImagem = null;
      });
      return;
    }
    final ok = await confirmar(context, titulo: 'Remover imagem', mensagem: 'Remover a imagem deste produto?',
        acao: 'Remover', perigoso: true);
    if (!ok) return;
    try {
      final atualizado = await ref.read(produtosRepositoryProvider).removerImagem(_produto!.id);
      setState(() => _produto = atualizado);
      ref.invalidate(produtosPaginaProvider);
    } catch (e) {
      if (mounted) mostrarErro(context, e);
    }
  }

  Future<void> _alternarStatus() async {
    final p = _produto!;
    if (p.ativo) {
      final ok = await confirmar(context,
          titulo: 'Inativar produto',
          mensagem: '"${p.nome}" deixará de aparecer nas vendas e no cardápio. O histórico é mantido.',
          acao: 'Inativar');
      if (!ok) return;
    }
    try {
      final atualizado = await ref.read(produtosRepositoryProvider).alterarStatus(p.id, !p.ativo);
      setState(() => _produto = atualizado);
      ref.invalidate(produtosPaginaProvider);
      if (mounted) mostrarSucesso(context, atualizado.ativo ? 'Produto ativado.' : 'Produto inativado.');
    } catch (e) {
      if (mounted) mostrarErro(context, e);
    }
  }

  Future<void> _excluir() async {
    final p = _produto!;
    final ok = await confirmar(context,
        titulo: 'Excluir produto',
        mensagem: 'Excluir "${p.nome}" definitivamente? Produtos com movimentações não podem ser excluídos '
            '— nesse caso, inative-o.',
        acao: 'Excluir',
        perigoso: true);
    if (!ok) return;
    try {
      await ref.read(produtosRepositoryProvider).excluir(p.id);
      ref.invalidate(produtosPaginaProvider);
      if (mounted) {
        mostrarSucesso(context, 'Produto excluído.');
        context.go('/produtos');
      }
    } catch (e) {
      if (mounted) mostrarErro(context, e);
    }
  }

  // ---------------------------------------------------------------- validações de formato

  String? _obrigatorio(String? v) => (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null;

  String? _decimal(String? v, {bool obrigatorio = false, bool positivo = false}) {
    if (v == null || v.trim().isEmpty) return obrigatorio ? 'Campo obrigatório' : null;
    final n = lerDecimal(v);
    if (n == null) return 'Número inválido';
    if (n < 0 || (positivo && n == 0)) return positivo ? 'Deve ser maior que zero' : 'Não pode ser negativo';
    return null;
  }

  // ---------------------------------------------------------------- interface

  @override
  Widget build(BuildContext context) {
    final p = _produto;
    final categoriasDisponiveis =
        widget.categorias.where((c) => c.ativo || c.id == _categoriaId).toList();
    final sigla = _unidadeEstoque?.sigla ?? '';

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CabecalhoPagina(
            titulo: _edicao ? p!.nome : 'Novo produto',
            subtitulo: _edicao ? (p!.ativo ? 'Produto ativo' : 'Produto inativo') : null,
            acoes: [
              OutlinedButton.icon(
                onPressed: () => context.go('/produtos'),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Voltar'),
              ),
              if (_edicao) ...[
                OutlinedButton(onPressed: _alternarStatus, child: Text(p!.ativo ? 'Inativar' : 'Ativar')),
                OutlinedButton(
                  onPressed: _excluir,
                  style: OutlinedButton.styleFrom(foregroundColor: AppCores.perigo),
                  child: const Text('Excluir'),
                ),
              ],
              FilledButton.icon(
                onPressed: _salvando ? null : _salvar,
                icon: _salvando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: const Text('Salvar'),
              ),
            ],
          ),
          _Secao(
            titulo: 'Identificação',
            children: [
              _Linha([
                TextFormField(
                  controller: _nome,
                  decoration: InputDecoration(labelText: 'Nome *', errorText: _erro?.campos['nome']),
                  maxLength: 120,
                  validator: _obrigatorio,
                ),
                TextFormField(
                  controller: _codigo,
                  decoration: InputDecoration(
                    labelText: 'Código interno',
                    helperText: 'Opcional',
                    errorText: _erro?.campos['codigoInterno'],
                  ),
                  maxLength: 30,
                ),
              ]),
              TextFormField(
                controller: _descricao,
                decoration: const InputDecoration(labelText: 'Descrição', helperText: 'Exibida no cardápio digital'),
                maxLines: 3,
                maxLength: 1000,
              ),
              const SizedBox(height: 12),
              _Linha([
                DropdownButtonFormField<String?>(
                  initialValue: _categoriaId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Sem categoria')),
                    for (final c in categoriasDisponiveis) DropdownMenuItem(value: c.id, child: Text(c.nome)),
                  ],
                  onChanged: (v) => setState(() => _categoriaId = v),
                ),
                DropdownButtonFormField<String?>(
                  initialValue: widget.fornecedores.any((f) => f.id == _fornecedorId) ? _fornecedorId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Fornecedor principal'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Nenhum')),
                    for (final f in widget.fornecedores)
                      DropdownMenuItem(value: f.id, child: Text(f.nomeExibicao, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _fornecedorId = v),
                ),
              ]),
              const SizedBox(height: 16),
              Text('Tipo do produto', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<TipoProduto>(
                segments: [
                  for (final t in TipoProduto.values) ButtonSegment(value: t, label: Text(t.rotulo)),
                ],
                selected: {_tipo},
                onSelectionChanged: (s) => setState(() => _tipo = s.first),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_tipo.ajuda, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ),
            ],
          ),
          _Secao(
            titulo: 'Estoque e custos',
            children: [
              _Linha([
                DropdownButtonFormField<String>(
                  initialValue: _unidadeId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Unidade de estoque *',
                    helperText: 'Compras em kg, litro, caixa etc. são convertidas para esta unidade',
                    helperMaxLines: 2,
                    errorText: _erro?.campos['unidadeEstoqueId'],
                  ),
                  items: [
                    for (final u in _unidadesBase) DropdownMenuItem(value: u.id, child: Text(u.descricao)),
                  ],
                  validator: (v) => v == null ? 'Selecione a unidade' : null,
                  onChanged: (v) => setState(() => _unidadeId = v),
                ),
                TextFormField(
                  controller: _estoqueMinimo,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Estoque mínimo', suffixText: sigla),
                  validator: (v) => _decimal(v),
                ),
              ]),
              const SizedBox(height: 12),
              _Linha([
                TextFormField(
                  controller: _custo,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Custo de aquisição *',
                    prefixText: r'R$ ',
                    suffixText: sigla.isEmpty ? null : 'por $sigla',
                    errorText: _erro?.campos['custoMedio'],
                  ),
                  validator: (v) => _decimal(v, obrigatorio: true),
                ),
                if (_edicao)
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Estoque atual',
                      helperText: 'Alterado por movimentações de estoque',
                    ),
                    child: Text('${formatarQuantidade(p!.estoqueAtual)} ${p.unidadeEstoque.sigla}'),
                  ),
              ]),
            ],
          ),
          if (_tipo.vendavel)
            _Secao(
              titulo: 'Venda',
              children: [
                _Linha([
                  TextFormField(
                    controller: _preco,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Preço de venda *',
                      prefixText: r'R$ ',
                      errorText: _erro?.campos['precoVenda'],
                    ),
                    validator: (v) => _decimal(v, obrigatorio: true, positivo: true),
                  ),
                  if (_edicao)
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'Margem bruta (último valor salvo)'),
                      child: Text(formatarPercentual(p!.margemBrutaPercentual)),
                    ),
                ]),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Disponível no cardápio digital'),
                  subtitle: const Text('Clientes poderão pedir este produto pelo QR Code'),
                  value: _vendeNoCardapio,
                  onChanged: (v) => setState(() => _vendeNoCardapio = v),
                ),
              ],
            ),
          _Secao(
            titulo: 'Embalagens de compra',
            descricao: 'Ex.: "Caixa 12" para cervejas compradas em caixa, ou "Pacote 2 kg" para batata. '
                'Na compra, 1 embalagem será convertida automaticamente para a unidade de estoque.',
            children: [
              for (final (i, e) in _embalagens.indexed) _linhaEmbalagem(i, e, sigla),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _unidadesEmbalagem.isEmpty
                      ? null
                      : () => setState(() => _embalagens.add(_EmbalagemEdicao(unidadeId: _unidadesEmbalagem.first.id))),
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar embalagem'),
                ),
              ),
            ],
          ),
          _Secao(
            titulo: 'Imagem',
            children: [
              Row(
                children: [
                  ProdutoImagem(
                    bytes: _novaImagem,
                    url: ref.read(produtosRepositoryProvider).urlImagem(p?.imagemUrl),
                    tamanho: 96,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      OutlinedButton.icon(
                        onPressed: _escolherImagem,
                        icon: const Icon(Icons.upload),
                        label: Text(p?.imagemUrl == null && _novaImagem == null ? 'Escolher imagem' : 'Trocar imagem'),
                      ),
                      if (_novaImagem != null || p?.imagemUrl != null)
                        TextButton(onPressed: _removerImagem, child: const Text('Remover')),
                      if (_novaImagem != null)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text('A imagem será enviada ao salvar.'),
                        ),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _linhaEmbalagem(int indice, _EmbalagemEdicao e, String sigla) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              initialValue: e.unidadeId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: [for (final u in _unidadesEmbalagem) DropdownMenuItem(value: u.id, child: Text(u.nome))],
              onChanged: (v) => setState(() => e.unidadeId = v),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: e.descricao,
              decoration: const InputDecoration(labelText: 'Descrição', hintText: 'Caixa 12'),
              validator: _obrigatorio,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: e.fator,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Contém', suffixText: sigla),
              validator: (v) => _decimal(v, obrigatorio: true, positivo: true),
            ),
          ),
          IconButton(
            tooltip: 'Remover embalagem',
            padding: const EdgeInsets.only(top: 12),
            onPressed: () => setState(() => _embalagens.removeAt(indice).dispose()),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

/// Bloco do formulário com título.
class _Secao extends StatelessWidget {
  const _Secao({required this.titulo, this.descricao, required this.children});

  final String titulo;
  final String? descricao;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(titulo, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              if (descricao != null) ...[
                const SizedBox(height: 4),
                Text(descricao!, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Campos lado a lado em telas largas; empilhados no celular.
class _Linha extends StatelessWidget {
  const _Linha(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 600) {
        return Column(children: [
          for (final (i, c) in children.indexed) ...[if (i > 0) const SizedBox(height: 12), c],
        ]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, c) in children.indexed) ...[if (i > 0) const SizedBox(width: 16), Expanded(child: c)],
        ],
      );
    });
  }
}
