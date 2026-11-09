import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

class Indicadores {
  const Indicadores({
    required this.faturamento,
    required this.quantidadeVendas,
    required this.ticketMedio,
    required this.custo,
    required this.lucroBruto,
    required this.margemBruta,
    required this.despesas,
    required this.lucroLiquido,
    this.variacaoFaturamento,
    required this.faturamentoHoje,
    required this.vendasHoje,
    required this.faturamentoMes,
    required this.vendasMes,
  });

  final num faturamento;
  final int quantidadeVendas;
  final num ticketMedio;
  final num custo;
  final num lucroBruto;
  final num margemBruta;
  final num despesas;
  final num lucroLiquido;
  final num? variacaoFaturamento;
  final num faturamentoHoje;
  final int vendasHoje;
  final num faturamentoMes;
  final int vendasMes;

  factory Indicadores.fromJson(Map<String, dynamic> j) => Indicadores(
        faturamento: numDoJson(j['faturamento']) ?? 0,
        quantidadeVendas: (j['quantidadeVendas'] as num?)?.toInt() ?? 0,
        ticketMedio: numDoJson(j['ticketMedio']) ?? 0,
        custo: numDoJson(j['custo']) ?? 0,
        lucroBruto: numDoJson(j['lucroBruto']) ?? 0,
        margemBruta: numDoJson(j['margemBruta']) ?? 0,
        despesas: numDoJson(j['despesas']) ?? 0,
        lucroLiquido: numDoJson(j['lucroLiquido']) ?? 0,
        variacaoFaturamento: numDoJson(j['variacaoFaturamento']),
        faturamentoHoje: numDoJson(j['faturamentoHoje']) ?? 0,
        vendasHoje: (j['vendasHoje'] as num?)?.toInt() ?? 0,
        faturamentoMes: numDoJson(j['faturamentoMes']) ?? 0,
        vendasMes: (j['vendasMes'] as num?)?.toInt() ?? 0,
      );
}

class PontoDia {
  const PontoDia(this.data, this.faturamento, this.lucroBruto, this.quantidade);
  final DateTime data;
  final num faturamento;
  final num lucroBruto;
  final int quantidade;

  factory PontoDia.fromJson(Map<String, dynamic> j) => PontoDia(DateTime.parse(j['data'] as String),
      numDoJson(j['faturamento']) ?? 0, numDoJson(j['lucroBruto']) ?? 0, (j['quantidade'] as num).toInt());
}

class PontoHora {
  const PontoHora(this.hora, this.faturamento, this.quantidade);
  final int hora;
  final num faturamento;
  final int quantidade;

  factory PontoHora.fromJson(Map<String, dynamic> j) =>
      PontoHora((j['hora'] as num).toInt(), numDoJson(j['faturamento']) ?? 0, (j['quantidade'] as num).toInt());
}

class TotalForma {
  const TotalForma(this.forma, this.total, this.quantidade);
  final String forma;
  final num total;
  final int quantidade;

  String get rotulo => switch (forma) {
        'DINHEIRO' => 'Dinheiro',
        'PIX' => 'PIX',
        'CARTAO_DEBITO' => 'Débito',
        'CARTAO_CREDITO' => 'Crédito',
        _ => 'Outros',
      };

  factory TotalForma.fromJson(Map<String, dynamic> j) =>
      TotalForma(j['forma'] as String, numDoJson(j['total']) ?? 0, (j['quantidade'] as num).toInt());
}

class TotalCategoria {
  const TotalCategoria(this.categoria, this.faturamento, this.lucroBruto);
  final String categoria;
  final num faturamento;
  final num lucroBruto;

  factory TotalCategoria.fromJson(Map<String, dynamic> j) =>
      TotalCategoria(j['categoria'] as String, numDoJson(j['faturamento']) ?? 0, numDoJson(j['lucroBruto']) ?? 0);
}

class ProdutoRanking {
  const ProdutoRanking({
    required this.produto,
    required this.quantidade,
    required this.faturamento,
    required this.custo,
    required this.lucroBruto,
    required this.margem,
    required this.precoMedio,
    required this.custoUnitario,
    required this.lucroUnitario,
  });

  final String produto;
  final num quantidade;
  final num faturamento;
  final num custo;
  final num lucroBruto;
  final num margem;
  final num precoMedio;
  final num custoUnitario;
  final num lucroUnitario;

  factory ProdutoRanking.fromJson(Map<String, dynamic> j) => ProdutoRanking(
        produto: j['produto'] as String,
        quantidade: numDoJson(j['quantidade']) ?? 0,
        faturamento: numDoJson(j['faturamento']) ?? 0,
        custo: numDoJson(j['custo']) ?? 0,
        lucroBruto: numDoJson(j['lucroBruto']) ?? 0,
        margem: numDoJson(j['margem']) ?? 0,
        precoMedio: numDoJson(j['precoMedio']) ?? 0,
        custoUnitario: numDoJson(j['custoUnitario']) ?? 0,
        lucroUnitario: numDoJson(j['lucroUnitario']) ?? 0,
      );
}

class ProdutoGiro {
  const ProdutoGiro(this.produto, this.quantidadeVendida, this.estoqueAtual, this.unidade, this.valorParado);
  final String produto;
  final num quantidadeVendida;
  final num? estoqueAtual;
  final String unidade;
  final num valorParado;

  factory ProdutoGiro.fromJson(Map<String, dynamic> j) => ProdutoGiro(j['produto'] as String,
      numDoJson(j['quantidadeVendida']) ?? 0, numDoJson(j['estoqueAtual']), j['unidade'] as String? ?? '',
      numDoJson(j['valorParado']) ?? 0);
}

class ItemEstoque {
  const ItemEstoque(this.produto, this.atual, this.minimo, this.unidade);
  final String produto;
  final num atual;
  final num minimo;
  final String unidade;

  factory ItemEstoque.fromJson(Map<String, dynamic> j) => ItemEstoque(j['produto'] as String,
      numDoJson(j['atual']) ?? 0, numDoJson(j['minimo']) ?? 0, j['unidade'] as String? ?? '');
}

class Painel {
  const Painel({
    required this.inicio,
    required this.fim,
    required this.indicadores,
    required this.vendasPorDia,
    required this.vendasPorHora,
    required this.formasPagamento,
    required this.porCategoria,
    required this.maisVendidos,
    required this.maisLucrativos,
    required this.baixoGiro,
    required this.valorEstoque,
    required this.produtosAbaixoMinimo,
    required this.abaixoMinimo,
  });

  final DateTime inicio;
  final DateTime fim;
  final Indicadores indicadores;
  final List<PontoDia> vendasPorDia;
  final List<PontoHora> vendasPorHora;
  final List<TotalForma> formasPagamento;
  final List<TotalCategoria> porCategoria;
  final List<ProdutoRanking> maisVendidos;
  final List<ProdutoRanking> maisLucrativos;
  final List<ProdutoGiro> baixoGiro;
  final num valorEstoque;
  final int produtosAbaixoMinimo;
  final List<ItemEstoque> abaixoMinimo;

  static List<T> _lista<T>(Object? v, T Function(Map<String, dynamic>) f) =>
      (v as List? ?? const []).map((e) => f(e as Map<String, dynamic>)).toList();

  factory Painel.fromJson(Map<String, dynamic> j) {
    final estoque = j['estoque'] as Map<String, dynamic>;
    return Painel(
      inicio: DateTime.parse(j['inicio'] as String),
      fim: DateTime.parse(j['fim'] as String),
      indicadores: Indicadores.fromJson(j['indicadores'] as Map<String, dynamic>),
      vendasPorDia: _lista(j['vendasPorDia'], PontoDia.fromJson),
      vendasPorHora: _lista(j['vendasPorHora'], PontoHora.fromJson),
      formasPagamento: _lista(j['formasPagamento'], TotalForma.fromJson),
      porCategoria: _lista(j['porCategoria'], TotalCategoria.fromJson),
      maisVendidos: _lista(j['maisVendidos'], ProdutoRanking.fromJson),
      maisLucrativos: _lista(j['maisLucrativos'], ProdutoRanking.fromJson),
      baixoGiro: _lista(j['baixoGiro'], ProdutoGiro.fromJson),
      valorEstoque: numDoJson(estoque['valorEstoque']) ?? 0,
      produtosAbaixoMinimo: (estoque['produtosAbaixoMinimo'] as num?)?.toInt() ?? 0,
      abaixoMinimo: _lista(estoque['abaixoMinimo'], ItemEstoque.fromJson),
    );
  }
}

class RelatoriosRepository {
  RelatoriosRepository(this._api);
  final ApiClient _api;

  Future<Painel> painel(DateTimeRange periodo) async => Painel.fromJson(await _api.get('/api/admin/relatorios/painel',
      query: {'inicio': dataParaApi(periodo.start), 'fim': dataParaApi(periodo.end)}) as Map<String, dynamic>);
}

final relatoriosRepositoryProvider = Provider((ref) => RelatoriosRepository(ref.watch(apiClientProvider)));

DateTime _hoje() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Dashboard: sempre os últimos 30 dias.
final painelDashboardProvider = FutureProvider.autoDispose<Painel>((ref) {
  final hoje = _hoje();
  return ref.watch(relatoriosRepositoryProvider).painel(DateTimeRange(start: hoje.subtract(const Duration(days: 29)), end: hoje));
});

enum PeriodoRapido {
  hoje('Hoje'),
  semana('7 dias'),
  mes30('30 dias'),
  esteMes('Este mês'),
  mesPassado('Mês passado');

  const PeriodoRapido(this.rotulo);
  final String rotulo;

  DateTimeRange intervalo() {
    final hoje = _hoje();
    return switch (this) {
      PeriodoRapido.hoje => DateTimeRange(start: hoje, end: hoje),
      PeriodoRapido.semana => DateTimeRange(start: hoje.subtract(const Duration(days: 6)), end: hoje),
      PeriodoRapido.mes30 => DateTimeRange(start: hoje.subtract(const Duration(days: 29)), end: hoje),
      PeriodoRapido.esteMes => DateTimeRange(start: DateTime(hoje.year, hoje.month), end: hoje),
      PeriodoRapido.mesPassado => DateTimeRange(
          start: DateTime(hoje.year, hoje.month - 1), end: DateTime(hoje.year, hoje.month).subtract(const Duration(days: 1))),
    };
  }
}

class PeriodoRelatorioController extends Notifier<DateTimeRange> {
  @override
  DateTimeRange build() => PeriodoRapido.mes30.intervalo();

  void mudar(DateTimeRange periodo) => state = periodo;
}

final periodoRelatorioProvider =
    NotifierProvider<PeriodoRelatorioController, DateTimeRange>(PeriodoRelatorioController.new);

final painelRelatorioProvider = FutureProvider.autoDispose<Painel>(
  (ref) => ref.watch(relatoriosRepositoryProvider).painel(ref.watch(periodoRelatorioProvider)),
);
