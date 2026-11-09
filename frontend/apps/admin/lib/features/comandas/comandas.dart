import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../vendas/vendas.dart';

// =============================================================================
// Modelos
// =============================================================================

enum StatusComanda { aberta, fechada, cancelada }

class ItemComanda {
  const ItemComanda({
    required this.id,
    required this.produtoId,
    required this.produtoNome,
    required this.quantidade,
    required this.precoUnitario,
    required this.total,
    this.observacao,
    this.lancadoEm,
  });

  final String id;
  final String produtoId;
  final String produtoNome;
  final num quantidade;
  final num precoUnitario;
  final num total;
  final String? observacao;
  final DateTime? lancadoEm;

  factory ItemComanda.fromJson(Map<String, dynamic> j) => ItemComanda(
        id: j['id'] as String,
        produtoId: j['produtoId'] as String,
        produtoNome: j['produtoNome'] as String,
        quantidade: numDoJson(j['quantidade']) ?? 0,
        precoUnitario: numDoJson(j['precoUnitario']) ?? 0,
        total: numDoJson(j['total']) ?? 0,
        observacao: j['observacao'] as String?,
        lancadoEm: dataDoJson(j['lancadoEm']),
      );
}

class Comanda {
  const Comanda({
    required this.id,
    required this.numero,
    required this.clienteNome,
    this.local,
    this.observacao,
    required this.status,
    required this.total,
    required this.itens,
    this.vendaId,
    this.motivoCancelamento,
    this.abertaEm,
    this.fechadaEm,
    this.canceladaEm,
  });

  final String id;
  final int numero;
  final String clienteNome;
  final String? local;
  final String? observacao;
  final StatusComanda status;
  final num total;
  final List<ItemComanda> itens;
  final String? vendaId;
  final String? motivoCancelamento;
  final DateTime? abertaEm;
  final DateTime? fechadaEm;
  final DateTime? canceladaEm;

  bool get aberta => status == StatusComanda.aberta;
  num get quantidadeItens => itens.fold<num>(0, (s, i) => s + i.quantidade);

  factory Comanda.fromJson(Map<String, dynamic> j) => Comanda(
        id: j['id'] as String,
        numero: j['numero'] as int,
        clienteNome: j['clienteNome'] as String,
        local: j['local'] as String?,
        observacao: j['observacao'] as String?,
        status: switch (j['status'] as String) {
          'FECHADA' => StatusComanda.fechada,
          'CANCELADA' => StatusComanda.cancelada,
          _ => StatusComanda.aberta,
        },
        total: numDoJson(j['total']) ?? 0,
        itens: (j['itens'] as List).map((e) => ItemComanda.fromJson(e as Map<String, dynamic>)).toList(),
        vendaId: j['vendaId'] as String?,
        motivoCancelamento: j['motivoCancelamento'] as String?,
        abertaEm: dataDoJson(j['abertaEm']),
        fechadaEm: dataDoJson(j['fechadaEm']),
        canceladaEm: dataDoJson(j['canceladaEm']),
      );
}

// =============================================================================
// API
// =============================================================================

class ComandasRepository {
  ComandasRepository(this._api);
  final ApiClient _api;

  static const _base = '/api/admin/comandas';

  Comanda _de(Object? json) => Comanda.fromJson(json as Map<String, dynamic>);

  Future<List<Comanda>> abertas() async =>
      (await _api.get('$_base/abertas') as List).map((e) => Comanda.fromJson(e as Map<String, dynamic>)).toList();

  Future<PageResponse<Comanda>> historico({int pagina = 0}) async => PageResponse.fromJson(
        await _api.get(_base, query: {'page': pagina, 'size': 30}) as Map<String, dynamic>,
        Comanda.fromJson,
      );

  Future<Comanda> buscar(String id) async => _de(await _api.get('$_base/$id'));

  Future<Comanda> abrir({required String nome, String? local, String? observacao}) async =>
      _de(await _api.post(_base, corpo: {'clienteNome': nome, 'local': ?local, 'observacao': ?observacao}));

  Future<Comanda> alterar(String id, {required String nome, String? local, String? observacao}) async =>
      _de(await _api.put('$_base/$id', corpo: {'clienteNome': nome, 'local': ?local, 'observacao': ?observacao}));

  Future<Comanda> lancar(String id, String produtoId, {num quantidade = 1, String? observacao}) async =>
      _de(await _api.post('$_base/$id/itens',
          corpo: {'produtoId': produtoId, 'quantidade': quantidade, 'observacao': ?observacao}));

  /// [quantidade] nula = retira o item inteiro.
  Future<Comanda> retirar(String id, String itemId, {num? quantidade}) async =>
      _de(await _api.post('$_base/$id/itens/$itemId/retirar', corpo: {'quantidade': ?quantidade}));

  Future<Comanda> fechar(String id, FormaPagamento forma, {num? valorRecebido, num? desconto}) async =>
      _de(await _api.post('$_base/$id/fechar', corpo: {
        'formaPagamento': forma.api,
        'valorRecebido': ?valorRecebido,
        'desconto': ?desconto,
      }));

  Future<Comanda> cancelar(String id, String motivo) async =>
      _de(await _api.post('$_base/$id/cancelar', corpo: {'motivo': motivo}));
}

final comandasRepositoryProvider = Provider((ref) => ComandasRepository(ref.watch(apiClientProvider)));

final comandasAbertasProvider =
    FutureProvider.autoDispose<List<Comanda>>((ref) => ref.watch(comandasRepositoryProvider).abertas());

final comandaProvider = FutureProvider.autoDispose.family<Comanda, String>(
  (ref, id) => ref.watch(comandasRepositoryProvider).buscar(id),
);

class PaginaHistoricoComandas extends Notifier<int> {
  @override
  int build() => 0;

  void ir(int pagina) => state = pagina;
}

final paginaHistoricoComandasProvider =
    NotifierProvider<PaginaHistoricoComandas, int>(PaginaHistoricoComandas.new);

final historicoComandasProvider = FutureProvider.autoDispose<PageResponse<Comanda>>((ref) {
  final pagina = ref.watch(paginaHistoricoComandasProvider);
  return ref.watch(comandasRepositoryProvider).historico(pagina: pagina);
});
