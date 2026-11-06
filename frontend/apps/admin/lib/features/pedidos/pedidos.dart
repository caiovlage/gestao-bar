import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../vendas/vendas.dart';

// =============================================================================
// Modelos
// =============================================================================

enum StatusPreparo {
  recebido('RECEBIDO', 'Novo', Icons.notifications_active_outlined, Color(0xFF2563EB)),
  aceito('ACEITO', 'Aceito', Icons.thumb_up_alt_outlined, Color(0xFF7C3AED)),
  emPreparo('EM_PREPARO', 'Em preparo', Icons.soup_kitchen_outlined, Color(0xFFB45309)),
  pronto('PRONTO', 'Pronto', Icons.room_service_outlined, Color(0xFF15803D)),
  entregue('ENTREGUE', 'Entregue', Icons.done_all, Color(0xFF475569)),
  cancelado('CANCELADO', 'Cancelado', Icons.cancel_outlined, Color(0xFFB91C1C));

  const StatusPreparo(this.api, this.rotulo, this.icone, this.cor);
  final String api;
  final String rotulo;
  final IconData icone;
  final Color cor;

  static StatusPreparo fromApi(String v) => values.firstWhere((s) => s.api == v);

  /// Próximo passo do preparo e o texto do botão que o executa.
  (StatusPreparo, String)? get proximo => switch (this) {
        aceito => (emPreparo, 'Iniciar preparo'),
        emPreparo => (pronto, 'Marcar pronto'),
        pronto => (entregue, 'Marcar entregue'),
        _ => null,
      };
}

class ItemPedido {
  const ItemPedido(this.produtoNome, this.quantidade, this.precoUnitario, this.total, this.observacao);

  final String produtoNome;
  final int quantidade;
  final num precoUnitario;
  final num total;
  final String? observacao;

  factory ItemPedido.fromJson(Map<String, dynamic> j) => ItemPedido(
        j['produtoNome'] as String,
        j['quantidade'] as int,
        numDoJson(j['precoUnitario']) ?? 0,
        numDoJson(j['total']) ?? 0,
        j['observacao'] as String?,
      );
}

class Pedido {
  const Pedido({
    required this.id,
    required this.numero,
    required this.clienteNome,
    required this.local,
    this.observacao,
    required this.status,
    required this.pago,
    required this.financeiroCancelado,
    required this.total,
    required this.itens,
    required this.estoqueReservado,
    this.motivoCancelamento,
    this.vendaId,
    this.criadoEm,
    this.pagoEm,
  });

  final String id;
  final int numero;
  final String clienteNome;
  final String local;
  final String? observacao;
  final StatusPreparo status;
  final bool pago;
  final bool financeiroCancelado;
  final num total;
  final List<ItemPedido> itens;
  final bool estoqueReservado;
  final String? motivoCancelamento;
  final String? vendaId;
  final DateTime? criadoEm;
  final DateTime? pagoEm;

  bool get cancelado => status == StatusPreparo.cancelado;
  bool get podeReceber => !pago && !cancelado && status != StatusPreparo.recebido;

  factory Pedido.fromJson(Map<String, dynamic> j) => Pedido(
        id: j['id'] as String,
        numero: j['numero'] as int,
        clienteNome: j['clienteNome'] as String,
        local: j['local'] as String,
        observacao: j['observacao'] as String?,
        status: StatusPreparo.fromApi(j['statusPreparo'] as String),
        pago: j['statusFinanceiro'] == 'PAGO',
        financeiroCancelado: j['statusFinanceiro'] == 'CANCELADO',
        total: numDoJson(j['total']) ?? 0,
        itens: (j['itens'] as List).map((e) => ItemPedido.fromJson(e as Map<String, dynamic>)).toList(),
        estoqueReservado: j['estoqueReservado'] as bool? ?? false,
        motivoCancelamento: j['motivoCancelamento'] as String?,
        vendaId: j['vendaId'] as String?,
        criadoEm: dataDoJson(j['criadoEm']),
        pagoEm: dataDoJson(j['pagoEm']),
      );
}

// =============================================================================
// API
// =============================================================================

class PedidosRepository {
  PedidosRepository(this._api);
  final ApiClient _api;

  static const _base = '/api/admin/pedidos';

  Future<List<Pedido>> emAndamento() async => (await _api.get('$_base/em-andamento') as List)
      .map((e) => Pedido.fromJson(e as Map<String, dynamic>))
      .toList();

  Future<PageResponse<Pedido>> historico({int pagina = 0}) async => PageResponse.fromJson(
        await _api.get(_base, query: {'page': pagina, 'size': 30}) as Map<String, dynamic>,
        Pedido.fromJson,
      );

  Future<Pedido> _acao(String id, String acao, [Object? corpo]) async =>
      Pedido.fromJson(await _api.post('$_base/$id/$acao', corpo: corpo ?? {}) as Map<String, dynamic>);

  Future<Pedido> aceitar(String id) => _acao(id, 'aceitar');

  Future<Pedido> avancar(String id, StatusPreparo status) => _acao(id, 'status', {'status': status.api});

  Future<Pedido> cancelar(String id, String motivo) => _acao(id, 'cancelar', {'motivo': motivo});

  Future<Pedido> pagar(String id, FormaPagamento forma, {num? valorRecebido, num? desconto}) =>
      _acao(id, 'pagar', {
        'formaPagamento': forma.api,
        'valorRecebido': ?valorRecebido,
        'desconto': ?desconto,
      });
}

final pedidosRepositoryProvider = Provider((ref) => PedidosRepository(ref.watch(apiClientProvider)));

final pedidosEmAndamentoProvider =
    FutureProvider.autoDispose<List<Pedido>>((ref) => ref.watch(pedidosRepositoryProvider).emAndamento());

class PaginaHistoricoController extends Notifier<int> {
  @override
  int build() => 0;

  void ir(int pagina) => state = pagina;
}

final paginaHistoricoPedidosProvider =
    NotifierProvider<PaginaHistoricoController, int>(PaginaHistoricoController.new);

final historicoPedidosProvider = FutureProvider.autoDispose<PageResponse<Pedido>>((ref) {
  final pagina = ref.watch(paginaHistoricoPedidosProvider);
  return ref.watch(pedidosRepositoryProvider).historico(pagina: pagina);
});
