import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../unidades/unidades.dart';

enum TipoProduto {
  revenda('REVENDA', 'Revenda', 'Vendido ao cliente (ex.: cerveja lata, lanche)'),
  ingrediente('INGREDIENTE', 'Ingrediente', 'Usado apenas em receitas (ex.: batata congelada)'),
  ambos('AMBOS', 'Revenda e ingrediente', 'Vendido e também usado em receitas');

  const TipoProduto(this.api, this.rotulo, this.ajuda);
  final String api;
  final String rotulo;
  final String ajuda;

  bool get vendavel => this != ingrediente;

  static TipoProduto fromApi(String valor) => values.firstWhere((t) => t.api == valor);
}

class Embalagem {
  const Embalagem({this.id, required this.unidade, required this.descricao, required this.fator});

  final String? id;
  final UnidadeMedida unidade;
  final String descricao;
  final num fator;

  factory Embalagem.fromJson(Map<String, dynamic> json) => Embalagem(
        id: json['id'] as String,
        unidade: UnidadeMedida.fromJson(json['unidade'] as Map<String, dynamic>),
        descricao: json['descricao'] as String,
        fator: numDoJson(json['fator'])!,
      );
}

class Produto {
  const Produto({
    required this.id,
    required this.nome,
    this.descricao,
    this.categoriaId,
    this.categoriaNome,
    required this.tipo,
    required this.unidadeEstoque,
    required this.custoMedio,
    this.precoVenda,
    this.margemBrutaPercentual,
    required this.estoqueAtual,
    required this.estoqueMinimo,
    required this.abaixoMinimo,
    this.fornecedorPrincipalId,
    this.codigoInterno,
    this.imagemUrl,
    required this.vendeNoCardapio,
    required this.ativo,
    required this.embalagens,
  });

  final String id;
  final String nome;
  final String? descricao;
  final String? categoriaId;
  final String? categoriaNome;
  final TipoProduto tipo;
  final UnidadeMedida unidadeEstoque;
  final num custoMedio;
  final num? precoVenda;
  final num? margemBrutaPercentual;
  final num estoqueAtual;
  final num estoqueMinimo;
  final bool abaixoMinimo;
  final String? fornecedorPrincipalId;
  final String? codigoInterno;
  final String? imagemUrl;
  final bool vendeNoCardapio;
  final bool ativo;
  final List<Embalagem> embalagens;

  factory Produto.fromJson(Map<String, dynamic> json) {
    final categoria = json['categoria'] as Map<String, dynamic>?;
    return Produto(
      id: json['id'] as String,
      nome: json['nome'] as String,
      descricao: json['descricao'] as String?,
      categoriaId: categoria?['id'] as String?,
      categoriaNome: categoria?['nome'] as String?,
      tipo: TipoProduto.fromApi(json['tipo'] as String),
      unidadeEstoque: UnidadeMedida.fromJson(json['unidadeEstoque'] as Map<String, dynamic>),
      custoMedio: numDoJson(json['custoMedio']) ?? 0,
      precoVenda: numDoJson(json['precoVenda']),
      margemBrutaPercentual: numDoJson(json['margemBrutaPercentual']),
      estoqueAtual: numDoJson(json['estoqueAtual']) ?? 0,
      estoqueMinimo: numDoJson(json['estoqueMinimo']) ?? 0,
      abaixoMinimo: json['abaixoMinimo'] as bool,
      fornecedorPrincipalId: json['fornecedorPrincipalId'] as String?,
      codigoInterno: json['codigoInterno'] as String?,
      imagemUrl: json['imagemUrl'] as String?,
      vendeNoCardapio: json['vendeNoCardapio'] as bool,
      ativo: json['ativo'] as bool,
      embalagens: (json['embalagens'] as List)
          .map((e) => Embalagem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Dados enviados ao criar/editar um produto.
class ProdutoForm {
  const ProdutoForm({
    required this.nome,
    this.descricao,
    this.categoriaId,
    required this.tipo,
    required this.unidadeEstoqueId,
    required this.custoMedio,
    this.precoVenda,
    required this.estoqueMinimo,
    this.fornecedorPrincipalId,
    this.codigoInterno,
    required this.vendeNoCardapio,
    required this.embalagens,
  });

  final String nome;
  final String? descricao;
  final String? categoriaId;
  final TipoProduto tipo;
  final String unidadeEstoqueId;
  final num custoMedio;
  final num? precoVenda;
  final num estoqueMinimo;
  final String? fornecedorPrincipalId;
  final String? codigoInterno;
  final bool vendeNoCardapio;
  final List<({String? id, String unidadeId, String descricao, num fator})> embalagens;

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'descricao': descricao,
        'categoriaId': categoriaId,
        'tipo': tipo.api,
        'unidadeEstoqueId': unidadeEstoqueId,
        'custoMedio': custoMedio,
        'precoVenda': precoVenda,
        'estoqueMinimo': estoqueMinimo,
        'fornecedorPrincipalId': fornecedorPrincipalId,
        'codigoInterno': codigoInterno,
        'vendeNoCardapio': vendeNoCardapio,
        'embalagens': [
          for (final e in embalagens)
            {'id': e.id, 'unidadeId': e.unidadeId, 'descricao': e.descricao, 'fator': e.fator},
        ],
      };
}

class ProdutosRepository {
  ProdutosRepository(this._api);
  final ApiClient _api;

  static const _base = '/api/admin/produtos';

  String? urlImagem(String? caminho) => _api.urlImagem(caminho);

  Future<PageResponse<Produto>> pesquisar(FiltroProdutos f) async {
    final dados = await _api.get(_base, query: {
      'nome': f.nome,
      'categoriaId': f.categoriaId,
      'tipo': f.tipo?.api,
      'ativo': f.ativo,
      'page': f.pagina,
      'size': 20,
    });
    return PageResponse.fromJson(dados as Map<String, dynamic>, Produto.fromJson);
  }

  Future<Produto> buscar(String id) async =>
      Produto.fromJson(await _api.get('$_base/$id') as Map<String, dynamic>);

  /// Produto com o código exato (barras/QR). Lança [ApiException] com status 404 se não existir.
  Future<Produto> buscarPorCodigo(String codigo) async =>
      Produto.fromJson(await _api.get('$_base/por-codigo', query: {'codigo': codigo}) as Map<String, dynamic>);

  Future<Produto> salvar(String? id, ProdutoForm form) async {
    final dados = id == null
        ? await _api.post(_base, corpo: form.toJson())
        : await _api.put('$_base/$id', corpo: form.toJson());
    return Produto.fromJson(dados as Map<String, dynamic>);
  }

  Future<Produto> alterarStatus(String id, bool ativo) async =>
      Produto.fromJson(await _api.patch('$_base/$id/status', corpo: {'ativo': ativo}) as Map<String, dynamic>);

  Future<void> excluir(String id) => _api.delete('$_base/$id');

  Future<Produto> enviarImagem(String id, List<int> bytes, String nomeArquivo) async => Produto.fromJson(
        await _api.enviarArquivo('$_base/$id/imagem', bytes: bytes, nomeArquivo: nomeArquivo)
            as Map<String, dynamic>,
      );

  Future<Produto> removerImagem(String id) async =>
      Produto.fromJson(await _api.delete('$_base/$id/imagem') as Map<String, dynamic>);
}

final produtosRepositoryProvider = Provider((ref) => ProdutosRepository(ref.watch(apiClientProvider)));

class FiltroProdutos {
  const FiltroProdutos({this.nome = '', this.categoriaId, this.tipo, this.ativo = true, this.pagina = 0});

  final String nome;
  final String? categoriaId;
  final TipoProduto? tipo;

  /// true = ativos, false = inativos, null = todos.
  final bool? ativo;
  final int pagina;
}

/// Filtros da listagem; mantidos ao navegar para o formulário e voltar.
class FiltroProdutosController extends Notifier<FiltroProdutos> {
  @override
  FiltroProdutos build() => const FiltroProdutos();

  void nome(String nome) => state = FiltroProdutos(
      nome: nome, categoriaId: state.categoriaId, tipo: state.tipo, ativo: state.ativo);

  void categoria(String? id) => state = FiltroProdutos(
      nome: state.nome, categoriaId: id, tipo: state.tipo, ativo: state.ativo);

  void tipo(TipoProduto? tipo) => state = FiltroProdutos(
      nome: state.nome, categoriaId: state.categoriaId, tipo: tipo, ativo: state.ativo);

  void ativo(bool? ativo) => state = FiltroProdutos(
      nome: state.nome, categoriaId: state.categoriaId, tipo: state.tipo, ativo: ativo);

  void pagina(int pagina) => state = FiltroProdutos(
      nome: state.nome, categoriaId: state.categoriaId, tipo: state.tipo, ativo: state.ativo, pagina: pagina);
}

final filtroProdutosProvider =
    NotifierProvider<FiltroProdutosController, FiltroProdutos>(FiltroProdutosController.new);

final produtosPaginaProvider = FutureProvider.autoDispose<PageResponse<Produto>>(
  (ref) => ref.watch(produtosRepositoryProvider).pesquisar(ref.watch(filtroProdutosProvider)),
);
