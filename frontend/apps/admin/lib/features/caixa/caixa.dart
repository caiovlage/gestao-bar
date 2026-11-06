import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

class TotaisCaixa {
  const TotaisCaixa({
    required this.quantidadeVendas,
    required this.totalVendas,
    required this.dinheiro,
    required this.pix,
    required this.cartaoDebito,
    required this.cartaoCredito,
    required this.outros,
    required this.suprimentos,
    required this.retiradas,
    required this.saldoEsperado,
  });

  final int quantidadeVendas;
  final num totalVendas;
  final num dinheiro;
  final num pix;
  final num cartaoDebito;
  final num cartaoCredito;
  final num outros;
  final num suprimentos;
  final num retiradas;

  /// Dinheiro que deve estar na gaveta: inicial + vendas em dinheiro + suprimentos − retiradas.
  final num saldoEsperado;

  factory TotaisCaixa.fromJson(Map<String, dynamic> j) => TotaisCaixa(
        quantidadeVendas: j['quantidadeVendas'] as int? ?? 0,
        totalVendas: numDoJson(j['totalVendas']) ?? 0,
        dinheiro: numDoJson(j['dinheiro']) ?? 0,
        pix: numDoJson(j['pix']) ?? 0,
        cartaoDebito: numDoJson(j['cartaoDebito']) ?? 0,
        cartaoCredito: numDoJson(j['cartaoCredito']) ?? 0,
        outros: numDoJson(j['outros']) ?? 0,
        suprimentos: numDoJson(j['suprimentos']) ?? 0,
        retiradas: numDoJson(j['retiradas']) ?? 0,
        saldoEsperado: numDoJson(j['saldoEsperado']) ?? 0,
      );
}

class MovimentoCaixa {
  const MovimentoCaixa(this.id, this.suprimento, this.valor, this.motivo, this.dataHora);

  final String id;
  final bool suprimento;
  final num valor;
  final String motivo;
  final DateTime? dataHora;

  factory MovimentoCaixa.fromJson(Map<String, dynamic> j) => MovimentoCaixa(
        j['id'] as String,
        j['tipo'] == 'SUPRIMENTO',
        numDoJson(j['valor']) ?? 0,
        j['motivo'] as String,
        dataDoJson(j['dataHora']),
      );
}

class Caixa {
  const Caixa({
    required this.id,
    required this.aberto,
    this.abertoEm,
    this.fechadoEm,
    required this.saldoInicial,
    required this.totais,
    required this.lucroBruto,
    required this.vendasCanceladas,
    this.saldoContado,
    this.diferenca,
    this.observacaoAbertura,
    this.observacaoFechamento,
    required this.movimentacoes,
  });

  final String id;
  final bool aberto;
  final DateTime? abertoEm;
  final DateTime? fechadoEm;
  final num saldoInicial;
  final TotaisCaixa totais;
  final num lucroBruto;
  final int vendasCanceladas;
  final num? saldoContado;
  final num? diferenca;
  final String? observacaoAbertura;
  final String? observacaoFechamento;
  final List<MovimentoCaixa> movimentacoes;

  factory Caixa.fromJson(Map<String, dynamic> j) => Caixa(
        id: j['id'] as String,
        aberto: j['status'] == 'ABERTO',
        abertoEm: dataDoJson(j['abertoEm']),
        fechadoEm: dataDoJson(j['fechadoEm']),
        saldoInicial: numDoJson(j['saldoInicial']) ?? 0,
        totais: TotaisCaixa.fromJson(j['totais'] as Map<String, dynamic>),
        lucroBruto: numDoJson(j['lucroBruto']) ?? 0,
        vendasCanceladas: j['vendasCanceladas'] as int? ?? 0,
        saldoContado: numDoJson(j['saldoContado']),
        diferenca: numDoJson(j['diferenca']),
        observacaoAbertura: j['observacaoAbertura'] as String?,
        observacaoFechamento: j['observacaoFechamento'] as String?,
        movimentacoes: (j['movimentacoes'] as List? ?? const [])
            .map((e) => MovimentoCaixa.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class CaixaRepository {
  CaixaRepository(this._api);
  final ApiClient _api;

  static const _base = '/api/admin/caixa';

  /// Caixa aberto, ou null se não houver.
  Future<Caixa?> atual() async {
    final dados = await _api.get('$_base/atual');
    return dados is Map<String, dynamic> ? Caixa.fromJson(dados) : null;
  }

  Future<Caixa> abrir(num saldoInicial, String? observacao) async => Caixa.fromJson(
      await _api.post('$_base/abrir', corpo: {'saldoInicial': saldoInicial, 'observacao': observacao})
          as Map<String, dynamic>);

  Future<Caixa> movimentar({required bool suprimento, required num valor, required String motivo}) async =>
      Caixa.fromJson(await _api.post('$_base/movimentacoes', corpo: {
        'tipo': suprimento ? 'SUPRIMENTO' : 'RETIRADA',
        'valor': valor,
        'motivo': motivo,
      }) as Map<String, dynamic>);

  Future<Caixa> fechar(num saldoContado, String? observacao) async => Caixa.fromJson(
      await _api.post('$_base/fechar', corpo: {'saldoContado': saldoContado, 'observacao': observacao})
          as Map<String, dynamic>);

  Future<PageResponse<Caixa>> historico() async =>
      PageResponse.fromJson(await _api.get('$_base/historico') as Map<String, dynamic>, Caixa.fromJson);

  Future<Caixa> buscar(String id) async => Caixa.fromJson(await _api.get('$_base/$id') as Map<String, dynamic>);
}

final caixaRepositoryProvider = Provider((ref) => CaixaRepository(ref.watch(apiClientProvider)));

final caixaAtualProvider = FutureProvider.autoDispose<Caixa?>((ref) => ref.watch(caixaRepositoryProvider).atual());

final historicoCaixasProvider = FutureProvider.autoDispose<PageResponse<Caixa>>(
  (ref) => ref.watch(caixaRepositoryProvider).historico(),
);
