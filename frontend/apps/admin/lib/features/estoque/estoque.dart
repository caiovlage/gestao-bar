import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

// =============================================================================
// Modelos
// =============================================================================

enum TipoMovimentacao {
  entradaManual('ENTRADA_MANUAL', 'Entrada manual'),
  entradaCompra('ENTRADA_COMPRA', 'Entrada por compra'),
  estornoVenda('ESTORNO_VENDA', 'Estorno de venda'),
  saidaVenda('SAIDA_VENDA', 'Venda'),
  consumoReceita('CONSUMO_RECEITA', 'Consumo em receita'),
  consumoInterno('CONSUMO_INTERNO', 'Consumo interno'),
  perda('PERDA', 'Perda / desperdício'),
  devolucaoFornecedor('DEVOLUCAO_FORNECEDOR', 'Devolução ao fornecedor'),
  ajusteInventario('AJUSTE_INVENTARIO', 'Ajuste de inventário');

  const TipoMovimentacao(this.api, this.rotulo);
  final String api;
  final String rotulo;

  /// Saídas que o operador registra manualmente.
  static const saidasManuais = [consumoInterno, perda, devolucaoFornecedor];

  static TipoMovimentacao fromApi(String valor) => values.firstWhere((t) => t.api == valor);
}

class PosicaoEstoque {
  const PosicaoEstoque({
    required this.produtoId,
    required this.nome,
    this.codigoInterno,
    this.categoria,
    required this.unidadeSigla,
    required this.quantidade,
    required this.reservada,
    required this.disponivel,
    required this.estoqueMinimo,
    required this.custoMedio,
    required this.valorEstoque,
    required this.abaixoMinimo,
    required this.ativo,
  });

  final String produtoId;
  final String nome;
  final String? codigoInterno;
  final String? categoria;
  final String unidadeSigla;
  final num quantidade;
  final num reservada;
  final num disponivel;
  final num estoqueMinimo;
  final num custoMedio;
  final num valorEstoque;
  final bool abaixoMinimo;
  final bool ativo;

  bool get zerado => quantidade <= 0;

  factory PosicaoEstoque.fromJson(Map<String, dynamic> j) => PosicaoEstoque(
        produtoId: j['produtoId'] as String,
        nome: j['nome'] as String,
        codigoInterno: j['codigoInterno'] as String?,
        categoria: j['categoria'] as String?,
        unidadeSigla: j['unidadeSigla'] as String,
        quantidade: numDoJson(j['quantidade']) ?? 0,
        reservada: numDoJson(j['reservada']) ?? 0,
        disponivel: numDoJson(j['disponivel']) ?? 0,
        estoqueMinimo: numDoJson(j['estoqueMinimo']) ?? 0,
        custoMedio: numDoJson(j['custoMedio']) ?? 0,
        valorEstoque: numDoJson(j['valorEstoque']) ?? 0,
        abaixoMinimo: j['abaixoMinimo'] as bool,
        ativo: j['ativo'] as bool,
      );
}

class ResumoEstoque {
  const ResumoEstoque(this.produtosAtivos, this.abaixoMinimo, this.zerados, this.valorTotal);

  final int produtosAtivos;
  final int abaixoMinimo;
  final int zerados;
  final num valorTotal;

  factory ResumoEstoque.fromJson(Map<String, dynamic> j) => ResumoEstoque(
        j['produtosAtivos'] as int,
        j['abaixoMinimo'] as int,
        j['zerados'] as int,
        numDoJson(j['valorTotal']) ?? 0,
      );
}

class Movimentacao {
  const Movimentacao({
    required this.id,
    required this.produtoId,
    required this.produtoNome,
    required this.unidadeSigla,
    required this.tipo,
    required this.quantidade,
    required this.saldoAnterior,
    required this.saldoPosterior,
    required this.custoUnitario,
    this.quantidadeInformada,
    required this.origem,
    this.observacao,
    required this.dataHora,
  });

  final String id;
  final String produtoId;
  final String produtoNome;
  final String unidadeSigla;
  final TipoMovimentacao tipo;
  final num quantidade;
  final num saldoAnterior;
  final num saldoPosterior;
  final num custoUnitario;
  final String? quantidadeInformada;
  final String origem;
  final String? observacao;
  final DateTime? dataHora;

  bool get entrada => quantidade > 0;

  factory Movimentacao.fromJson(Map<String, dynamic> j) => Movimentacao(
        id: j['id'] as String,
        produtoId: j['produtoId'] as String,
        produtoNome: j['produtoNome'] as String,
        unidadeSigla: j['unidadeSigla'] as String,
        tipo: TipoMovimentacao.fromApi(j['tipo'] as String),
        quantidade: numDoJson(j['quantidade']) ?? 0,
        saldoAnterior: numDoJson(j['saldoAnterior']) ?? 0,
        saldoPosterior: numDoJson(j['saldoPosterior']) ?? 0,
        custoUnitario: numDoJson(j['custoUnitario']) ?? 0,
        quantidadeInformada: j['quantidadeInformada'] as String?,
        origem: j['origem'] as String,
        observacao: j['observacao'] as String?,
        dataHora: dataDoJson(j['dataHora']),
      );
}

enum StatusInventario {
  aberto('ABERTO', 'Em andamento'),
  concluido('CONCLUIDO', 'Concluído'),
  cancelado('CANCELADO', 'Cancelado');

  const StatusInventario(this.api, this.rotulo);
  final String api;
  final String rotulo;

  static StatusInventario fromApi(String v) => values.firstWhere((s) => s.api == v);
}

class InventarioResumo {
  const InventarioResumo({
    required this.id,
    required this.descricao,
    this.categoria,
    required this.status,
    required this.totalItens,
    required this.itensContados,
    this.criadoEm,
    this.concluidoEm,
  });

  final String id;
  final String descricao;
  final String? categoria;
  final StatusInventario status;
  final int totalItens;
  final int itensContados;
  final DateTime? criadoEm;
  final DateTime? concluidoEm;

  factory InventarioResumo.fromJson(Map<String, dynamic> j) => InventarioResumo(
        id: j['id'] as String,
        descricao: j['descricao'] as String,
        categoria: j['categoria'] as String?,
        status: StatusInventario.fromApi(j['status'] as String),
        totalItens: j['totalItens'] as int,
        itensContados: j['itensContados'] as int,
        criadoEm: dataDoJson(j['criadoEm']),
        concluidoEm: dataDoJson(j['concluidoEm']),
      );
}

class ItemInventario {
  const ItemInventario({
    required this.produtoId,
    required this.produtoNome,
    this.categoria,
    required this.unidadeSigla,
    this.quantidadeSistema,
    this.quantidadeContada,
    this.diferenca,
    this.valorDiferenca,
  });

  final String produtoId;
  final String produtoNome;
  final String? categoria;
  final String unidadeSigla;
  final num? quantidadeSistema;
  final num? quantidadeContada;
  final num? diferenca;
  final num? valorDiferenca;

  factory ItemInventario.fromJson(Map<String, dynamic> j) => ItemInventario(
        produtoId: j['produtoId'] as String,
        produtoNome: j['produtoNome'] as String,
        categoria: j['categoria'] as String?,
        unidadeSigla: j['unidadeSigla'] as String,
        quantidadeSistema: numDoJson(j['quantidadeSistema']),
        quantidadeContada: numDoJson(j['quantidadeContada']),
        diferenca: numDoJson(j['diferenca']),
        valorDiferenca: numDoJson(j['valorDiferenca']),
      );
}

class InventarioDetalhe {
  const InventarioDetalhe({
    required this.id,
    required this.descricao,
    this.categoria,
    required this.status,
    this.observacao,
    this.criadoEm,
    this.concluidoEm,
    required this.totalItens,
    required this.itensContados,
    required this.itensComDiferenca,
    required this.itens,
  });

  final String id;
  final String descricao;
  final String? categoria;
  final StatusInventario status;
  final String? observacao;
  final DateTime? criadoEm;
  final DateTime? concluidoEm;
  final int totalItens;
  final int itensContados;
  final int itensComDiferenca;
  final List<ItemInventario> itens;

  bool get aberto => status == StatusInventario.aberto;

  factory InventarioDetalhe.fromJson(Map<String, dynamic> j) => InventarioDetalhe(
        id: j['id'] as String,
        descricao: j['descricao'] as String,
        categoria: j['categoria'] as String?,
        status: StatusInventario.fromApi(j['status'] as String),
        observacao: j['observacao'] as String?,
        criadoEm: dataDoJson(j['criadoEm']),
        concluidoEm: dataDoJson(j['concluidoEm']),
        totalItens: j['totalItens'] as int,
        itensContados: j['itensContados'] as int,
        itensComDiferenca: j['itensComDiferenca'] as int,
        itens: (j['itens'] as List).map((e) => ItemInventario.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

// =============================================================================
// Repositório
// =============================================================================

class EstoqueRepository {
  EstoqueRepository(this._api);
  final ApiClient _api;

  static const _base = '/api/admin/estoque';

  Future<PageResponse<PosicaoEstoque>> posicao(FiltroPosicao f) async {
    final dados = await _api.get(_base, query: {
      'nome': f.nome,
      'categoriaId': f.categoriaId,
      'situacao': f.situacao.api,
      'page': f.pagina,
      'size': 50,
    });
    return PageResponse.fromJson(dados as Map<String, dynamic>, PosicaoEstoque.fromJson);
  }

  Future<ResumoEstoque> resumo() async =>
      ResumoEstoque.fromJson(await _api.get('$_base/resumo') as Map<String, dynamic>);

  Future<PageResponse<Movimentacao>> movimentacoes(FiltroMovimentacoes f) async {
    final dados = await _api.get('$_base/movimentacoes', query: {
      'produtoId': f.produtoId,
      'tipo': f.tipo?.api,
      'inicio': f.periodo == null ? null : dataParaApi(f.periodo!.start),
      'fim': f.periodo == null ? null : dataParaApi(f.periodo!.end),
      'page': f.pagina,
      'size': 50,
    });
    return PageResponse.fromJson(dados as Map<String, dynamic>, Movimentacao.fromJson);
  }

  Future<Movimentacao> entrada({
    required String produtoId,
    required num quantidade,
    String? unidadeId,
    String? embalagemId,
    String? observacao,
  }) async =>
      Movimentacao.fromJson(await _api.post('$_base/entradas', corpo: {
        'produtoId': produtoId,
        'quantidade': quantidade,
        'unidadeId': unidadeId,
        'embalagemId': embalagemId,
        'observacao': observacao,
      }) as Map<String, dynamic>);

  Future<Movimentacao> saida({
    required String produtoId,
    required TipoMovimentacao tipo,
    required num quantidade,
    String? unidadeId,
    String? embalagemId,
    String? observacao,
  }) async =>
      Movimentacao.fromJson(await _api.post('$_base/saidas', corpo: {
        'produtoId': produtoId,
        'tipo': tipo.api,
        'quantidade': quantidade,
        'unidadeId': unidadeId,
        'embalagemId': embalagemId,
        'observacao': observacao,
      }) as Map<String, dynamic>);

  /// Retorna null quando a quantidade contada já era igual ao saldo (nenhum ajuste).
  Future<Movimentacao?> ajuste({
    required String produtoId,
    required num quantidadeContada,
    required String observacao,
  }) async {
    final dados = await _api.post('$_base/ajustes', corpo: {
      'produtoId': produtoId,
      'quantidadeContada': quantidadeContada,
      'observacao': observacao,
    });
    return dados is Map<String, dynamic> ? Movimentacao.fromJson(dados) : null;
  }

  Future<PageResponse<InventarioResumo>> inventarios() async {
    final dados = await _api.get('$_base/inventarios', query: {'size': 50});
    return PageResponse.fromJson(dados as Map<String, dynamic>, InventarioResumo.fromJson);
  }

  Future<InventarioDetalhe> criarInventario(String descricao, String? categoriaId) async =>
      InventarioDetalhe.fromJson(await _api.post('$_base/inventarios',
          corpo: {'descricao': descricao, 'categoriaId': categoriaId}) as Map<String, dynamic>);

  Future<InventarioDetalhe> inventario(String id) async =>
      InventarioDetalhe.fromJson(await _api.get('$_base/inventarios/$id') as Map<String, dynamic>);

  Future<InventarioDetalhe> salvarContagens(String id, Map<String, num?> contagens) async =>
      InventarioDetalhe.fromJson(await _api.put('$_base/inventarios/$id/contagens', corpo: {
        'contagens': [
          for (final e in contagens.entries) {'produtoId': e.key, 'quantidadeContada': e.value},
        ],
      }) as Map<String, dynamic>);

  Future<InventarioDetalhe> concluirInventario(String id, String? observacao) async => InventarioDetalhe.fromJson(
      await _api.post('$_base/inventarios/$id/concluir', corpo: {'observacao': observacao}) as Map<String, dynamic>);

  Future<InventarioDetalhe> cancelarInventario(String id, String? observacao) async => InventarioDetalhe.fromJson(
      await _api.post('$_base/inventarios/$id/cancelar', corpo: {'observacao': observacao}) as Map<String, dynamic>);
}

final estoqueRepositoryProvider = Provider((ref) => EstoqueRepository(ref.watch(apiClientProvider)));

// =============================================================================
// Estado da tela
// =============================================================================

enum SituacaoEstoque {
  todos('TODOS', 'Todos'),
  abaixoMinimo('ABAIXO_MINIMO', 'Abaixo do mínimo'),
  zerado('ZERADO', 'Zerados');

  const SituacaoEstoque(this.api, this.rotulo);
  final String api;
  final String rotulo;
}

class FiltroPosicao {
  const FiltroPosicao({this.nome = '', this.categoriaId, this.situacao = SituacaoEstoque.todos, this.pagina = 0});

  final String nome;
  final String? categoriaId;
  final SituacaoEstoque situacao;
  final int pagina;

  FiltroPosicao copiar({String? nome, String? Function()? categoriaId, SituacaoEstoque? situacao, int pagina = 0}) =>
      FiltroPosicao(
        nome: nome ?? this.nome,
        categoriaId: categoriaId == null ? this.categoriaId : categoriaId(),
        situacao: situacao ?? this.situacao,
        pagina: pagina,
      );
}

class FiltroPosicaoController extends Notifier<FiltroPosicao> {
  @override
  FiltroPosicao build() => const FiltroPosicao();

  void nome(String v) => state = state.copiar(nome: v);
  void categoria(String? v) => state = state.copiar(categoriaId: () => v);
  void situacao(SituacaoEstoque v) => state = state.copiar(situacao: v);
  void pagina(int p) => state = state.copiar(pagina: p);
}

final filtroPosicaoProvider = NotifierProvider<FiltroPosicaoController, FiltroPosicao>(FiltroPosicaoController.new);

final posicaoEstoqueProvider = FutureProvider.autoDispose<PageResponse<PosicaoEstoque>>(
  (ref) => ref.watch(estoqueRepositoryProvider).posicao(ref.watch(filtroPosicaoProvider)),
);

final resumoEstoqueProvider = FutureProvider.autoDispose<ResumoEstoque>(
  (ref) => ref.watch(estoqueRepositoryProvider).resumo(),
);

class FiltroMovimentacoes {
  const FiltroMovimentacoes({this.produtoId, this.produtoNome, this.tipo, this.periodo, this.pagina = 0});

  final String? produtoId;
  final String? produtoNome;
  final TipoMovimentacao? tipo;
  final DateTimeRange? periodo;
  final int pagina;
}

class FiltroMovimentacoesController extends Notifier<FiltroMovimentacoes> {
  @override
  FiltroMovimentacoes build() => const FiltroMovimentacoes();

  void produto(String? id, String? nome) =>
      state = FiltroMovimentacoes(produtoId: id, produtoNome: nome, tipo: state.tipo, periodo: state.periodo);

  void tipo(TipoMovimentacao? tipo) => state = FiltroMovimentacoes(
      produtoId: state.produtoId, produtoNome: state.produtoNome, tipo: tipo, periodo: state.periodo);

  void periodo(DateTimeRange? periodo) => state = FiltroMovimentacoes(
      produtoId: state.produtoId, produtoNome: state.produtoNome, tipo: state.tipo, periodo: periodo);

  void pagina(int pagina) => state = FiltroMovimentacoes(
      produtoId: state.produtoId,
      produtoNome: state.produtoNome,
      tipo: state.tipo,
      periodo: state.periodo,
      pagina: pagina);
}

final filtroMovimentacoesProvider =
    NotifierProvider<FiltroMovimentacoesController, FiltroMovimentacoes>(FiltroMovimentacoesController.new);

final movimentacoesProvider = FutureProvider.autoDispose<PageResponse<Movimentacao>>(
  (ref) => ref.watch(estoqueRepositoryProvider).movimentacoes(ref.watch(filtroMovimentacoesProvider)),
);

final inventariosProvider = FutureProvider.autoDispose<PageResponse<InventarioResumo>>(
  (ref) => ref.watch(estoqueRepositoryProvider).inventarios(),
);

final inventarioProvider = FutureProvider.autoDispose.family<InventarioDetalhe, String>(
  (ref, id) => ref.watch(estoqueRepositoryProvider).inventario(id),
);

/// Seção visível na tela de estoque (mantida ao voltar de um inventário).
enum SecaoEstoque { posicao, movimentacoes, inventarios }

class SecaoEstoqueController extends Notifier<SecaoEstoque> {
  @override
  SecaoEstoque build() => SecaoEstoque.posicao;

  void mudar(SecaoEstoque secao) => state = secao;
}

final secaoEstoqueProvider = NotifierProvider<SecaoEstoqueController, SecaoEstoque>(SecaoEstoqueController.new);
