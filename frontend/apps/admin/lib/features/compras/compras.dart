import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../unidades/unidades.dart';

enum StatusCompra {
  rascunho('RASCUNHO', 'Lista (rascunho)'),
  recebida('RECEBIDA', 'Recebida'),
  cancelada('CANCELADA', 'Cancelada');

  const StatusCompra(this.api, this.rotulo);
  final String api;
  final String rotulo;

  static StatusCompra fromApi(String v) => values.firstWhere((s) => s.api == v);
}

class SugestaoCompra {
  const SugestaoCompra({
    required this.produtoId,
    required this.nome,
    this.categoria,
    required this.unidadeSigla,
    required this.estoqueAtual,
    required this.estoqueMinimo,
    required this.sugerido,
    this.fornecedorId,
    this.fornecedor,
    this.embalagem,
    this.sugeridoEmbalagens,
    this.zerado = false,
  });

  final String produtoId;
  final String nome;
  final String? categoria;
  final String unidadeSigla;
  final num estoqueAtual;
  final num estoqueMinimo;
  final num sugerido;
  final String? fornecedorId;
  final String? fornecedor;
  final String? embalagem;
  final num? sugeridoEmbalagens;

  /// true = estoque zerado; false = abaixo do mínimo.
  final bool zerado;

  factory SugestaoCompra.fromJson(Map<String, dynamic> j) => SugestaoCompra(
        produtoId: j['produtoId'] as String,
        nome: j['nome'] as String,
        categoria: j['categoria'] as String?,
        unidadeSigla: j['unidadeSigla'] as String,
        estoqueAtual: numDoJson(j['estoqueAtual']) ?? 0,
        estoqueMinimo: numDoJson(j['estoqueMinimo']) ?? 0,
        sugerido: numDoJson(j['sugerido']) ?? 0,
        fornecedorId: j['fornecedorId'] as String?,
        fornecedor: j['fornecedor'] as String?,
        embalagem: j['embalagem'] as String?,
        sugeridoEmbalagens: numDoJson(j['sugeridoEmbalagens']),
        zerado: j['situacao'] == 'ZERADO',
      );
}

class OpcaoEmbalagem {
  const OpcaoEmbalagem(this.id, this.descricao, this.fator);
  final String id;
  final String descricao;
  final num fator;

  factory OpcaoEmbalagem.fromJson(Map<String, dynamic> j) =>
      OpcaoEmbalagem(j['id'] as String, j['descricao'] as String, numDoJson(j['fator']) ?? 1);
}

/// Produto que pode ser comprado (com controle de estoque).
class ProdutoCompravel {
  const ProdutoCompravel({
    required this.id,
    required this.nome,
    required this.unidadeId,
    required this.unidadeSigla,
    required this.grandeza,
    required this.custoMedio,
    this.fornecedorId,
    required this.embalagens,
  });

  final String id;
  final String nome;
  final String unidadeId;
  final String unidadeSigla;
  final Grandeza grandeza;
  final num custoMedio;
  final String? fornecedorId;
  final List<OpcaoEmbalagem> embalagens;

  factory ProdutoCompravel.fromJson(Map<String, dynamic> j) => ProdutoCompravel(
        id: j['id'] as String,
        nome: j['nome'] as String,
        unidadeId: j['unidadeId'] as String,
        unidadeSigla: j['unidadeSigla'] as String,
        grandeza: Grandeza.fromApi(j['grandeza'] as String),
        custoMedio: numDoJson(j['custoMedio']) ?? 0,
        fornecedorId: j['fornecedorId'] as String?,
        embalagens: (j['embalagens'] as List).map((e) => OpcaoEmbalagem.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class ItemCompra {
  const ItemCompra({
    required this.produtoId,
    required this.produtoNome,
    required this.quantidade,
    this.unidadeId,
    this.embalagemId,
    required this.unidadeCompra,
    required this.quantidadeEstoque,
    required this.unidadeEstoque,
    required this.custoUnitario,
    required this.custoTotal,
  });

  final String produtoId;
  final String produtoNome;
  final num quantidade;
  final String? unidadeId;
  final String? embalagemId;
  final String unidadeCompra;
  final num quantidadeEstoque;
  final String unidadeEstoque;
  final num custoUnitario;
  final num custoTotal;

  factory ItemCompra.fromJson(Map<String, dynamic> j) => ItemCompra(
        produtoId: j['produtoId'] as String,
        produtoNome: j['produtoNome'] as String,
        quantidade: numDoJson(j['quantidade']) ?? 0,
        unidadeId: j['unidadeId'] as String?,
        embalagemId: j['embalagemId'] as String?,
        unidadeCompra: j['unidadeCompra'] as String,
        quantidadeEstoque: numDoJson(j['quantidadeEstoque']) ?? 0,
        unidadeEstoque: j['unidadeEstoque'] as String? ?? '',
        custoUnitario: numDoJson(j['custoUnitario']) ?? 0,
        custoTotal: numDoJson(j['custoTotal']) ?? 0,
      );
}

class Compra {
  const Compra({
    required this.id,
    required this.numero,
    required this.status,
    this.fornecedorId,
    this.fornecedor,
    this.observacao,
    required this.total,
    this.criadaEm,
    this.recebidaEm,
    required this.itens,
  });

  final String id;
  final int numero;
  final StatusCompra status;
  final String? fornecedorId;
  final String? fornecedor;
  final String? observacao;
  final num total;
  final DateTime? criadaEm;
  final DateTime? recebidaEm;
  final List<ItemCompra> itens;

  bool get editavel => status == StatusCompra.rascunho;

  factory Compra.fromJson(Map<String, dynamic> j) => Compra(
        id: j['id'] as String,
        numero: (j['numero'] as num).toInt(),
        status: StatusCompra.fromApi(j['status'] as String),
        fornecedorId: j['fornecedorId'] as String?,
        fornecedor: j['fornecedor'] as String?,
        observacao: j['observacao'] as String?,
        total: numDoJson(j['total']) ?? 0,
        criadaEm: dataDoJson(j['criadaEm']),
        recebidaEm: dataDoJson(j['recebidaEm']),
        itens: (j['itens'] as List).map((e) => ItemCompra.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class CompraResumo {
  const CompraResumo(this.id, this.numero, this.status, this.fornecedor, this.total, this.quantidadeItens, this.criadaEm);

  final String id;
  final int numero;
  final StatusCompra status;
  final String? fornecedor;
  final num total;
  final int quantidadeItens;
  final DateTime? criadaEm;

  factory CompraResumo.fromJson(Map<String, dynamic> j) => CompraResumo(
        j['id'] as String,
        (j['numero'] as num).toInt(),
        StatusCompra.fromApi(j['status'] as String),
        j['fornecedor'] as String?,
        numDoJson(j['total']) ?? 0,
        j['quantidadeItens'] as int? ?? 0,
        dataDoJson(j['criadaEm']),
      );
}

class HistoricoCusto {
  const HistoricoCusto(this.dataHora, this.compraNumero, this.fornecedor, this.quantidade, this.custoUnitario,
      this.custoMedioAnterior, this.custoMedioNovo);

  final DateTime? dataHora;
  final int compraNumero;
  final String? fornecedor;
  final num quantidade;
  final num custoUnitario;
  final num custoMedioAnterior;
  final num custoMedioNovo;

  factory HistoricoCusto.fromJson(Map<String, dynamic> j) => HistoricoCusto(
        dataDoJson(j['dataHora']),
        (j['compraNumero'] as num).toInt(),
        j['fornecedor'] as String?,
        numDoJson(j['quantidade']) ?? 0,
        numDoJson(j['custoUnitario']) ?? 0,
        numDoJson(j['custoMedioAnterior']) ?? 0,
        numDoJson(j['custoMedioNovo']) ?? 0,
      );
}

typedef ItemCompraForm = ({String produtoId, num quantidade, String? unidadeId, String? embalagemId, num custoUnitario});

class ComprasRepository {
  ComprasRepository(this._api);
  final ApiClient _api;

  static const _base = '/api/admin/compras';

  Future<List<SugestaoCompra>> sugestoes() async =>
      (await _api.get('$_base/sugestoes') as List).map((e) => SugestaoCompra.fromJson(e as Map<String, dynamic>)).toList();

  Future<List<ProdutoCompravel>> produtosCompraveis() async => (await _api.get('$_base/opcoes/produtos') as List)
      .map((e) => ProdutoCompravel.fromJson(e as Map<String, dynamic>))
      .toList();

  Future<Compra> criarDaSugestao(List<String> produtoIds, String? fornecedorId) async => Compra.fromJson(
      await _api.post('$_base/da-sugestao', corpo: {'produtoIds': produtoIds, 'fornecedorId': fornecedorId})
          as Map<String, dynamic>);

  Future<PageResponse<CompraResumo>> listar(String? status) async => PageResponse.fromJson(
      await _api.get(_base, query: {'status': status}) as Map<String, dynamic>, CompraResumo.fromJson);

  Future<Compra> buscar(String id) async => Compra.fromJson(await _api.get('$_base/$id') as Map<String, dynamic>);

  Future<Compra> salvar(String? id, {String? fornecedorId, String? observacao, required List<ItemCompraForm> itens}) async {
    final corpo = {
      'fornecedorId': fornecedorId,
      'observacao': observacao,
      'itens': [
        for (final i in itens)
          {
            'produtoId': i.produtoId,
            'quantidade': i.quantidade,
            'unidadeId': i.unidadeId,
            'embalagemId': i.embalagemId,
            'custoUnitario': i.custoUnitario,
          },
      ],
    };
    final dados = id == null ? await _api.post(_base, corpo: corpo) : await _api.put('$_base/$id', corpo: corpo);
    return Compra.fromJson(dados as Map<String, dynamic>);
  }

  Future<Compra> receber(String id) async =>
      Compra.fromJson(await _api.post('$_base/$id/receber', corpo: const {}) as Map<String, dynamic>);

  Future<Compra> cancelar(String id) async =>
      Compra.fromJson(await _api.post('$_base/$id/cancelar', corpo: const {}) as Map<String, dynamic>);

  Future<List<int>> exportar(String id, String formato) =>
      _api.obterBytes('$_base/$id/exportar', query: {'formato': formato});

  Future<List<HistoricoCusto>> historicoCustos(String produtoId) async =>
      (await _api.get('$_base/historico-custos', query: {'produtoId': produtoId}) as List)
          .map((e) => HistoricoCusto.fromJson(e as Map<String, dynamic>))
          .toList();
}

final comprasRepositoryProvider = Provider((ref) => ComprasRepository(ref.watch(apiClientProvider)));

final sugestoesCompraProvider = FutureProvider.autoDispose<List<SugestaoCompra>>(
  (ref) => ref.watch(comprasRepositoryProvider).sugestoes(),
);

final produtosCompraveisProvider = FutureProvider.autoDispose<List<ProdutoCompravel>>(
  (ref) => ref.watch(comprasRepositoryProvider).produtosCompraveis(),
);

final comprasProvider = FutureProvider.autoDispose.family<PageResponse<CompraResumo>, String?>(
  (ref, status) => ref.watch(comprasRepositoryProvider).listar(status),
);

final compraProvider = FutureProvider.autoDispose.family<Compra, String>(
  (ref, id) => ref.watch(comprasRepositoryProvider).buscar(id),
);

final historicoCustosProvider = FutureProvider.autoDispose.family<List<HistoricoCusto>, String>(
  (ref, produtoId) => ref.watch(comprasRepositoryProvider).historicoCustos(produtoId),
);
