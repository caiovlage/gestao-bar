import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

enum CategoriaDespesa {
  agua('AGUA', 'Água', Icons.water_drop_outlined),
  luz('LUZ', 'Luz', Icons.bolt_outlined),
  gas('GAS', 'Gás', Icons.local_fire_department_outlined),
  aluguel('ALUGUEL', 'Aluguel', Icons.home_work_outlined),
  manutencao('MANUTENCAO', 'Manutenção', Icons.build_outlined),
  limpeza('LIMPEZA', 'Materiais de limpeza', Icons.cleaning_services_outlined),
  funcionarios('FUNCIONARIOS', 'Funcionários', Icons.groups_outlined),
  impostos('IMPOSTOS', 'Impostos e taxas', Icons.account_balance_outlined),
  outros('OUTROS', 'Outros', Icons.more_horiz);

  const CategoriaDespesa(this.api, this.rotulo, this.icone);
  final String api;
  final String rotulo;
  final IconData icone;

  static CategoriaDespesa fromApi(String v) => values.firstWhere((c) => c.api == v);
}

class Despesa {
  const Despesa({
    required this.id,
    required this.descricao,
    required this.categoria,
    required this.valor,
    required this.data,
    this.fornecedorId,
    this.fornecedor,
    this.observacao,
  });

  final String id;
  final String descricao;
  final CategoriaDespesa categoria;
  final num valor;
  final DateTime data;
  final String? fornecedorId;
  final String? fornecedor;
  final String? observacao;

  factory Despesa.fromJson(Map<String, dynamic> j) => Despesa(
        id: j['id'] as String,
        descricao: j['descricao'] as String,
        categoria: CategoriaDespesa.fromApi(j['categoria'] as String),
        valor: numDoJson(j['valor']) ?? 0,
        data: DateTime.parse(j['data'] as String),
        fornecedorId: j['fornecedorId'] as String?,
        fornecedor: j['fornecedor'] as String?,
        observacao: j['observacao'] as String?,
      );
}

class ListaDespesas {
  const ListaDespesas(this.despesas, this.total, this.porCategoria);

  final List<Despesa> despesas;
  final num total;
  final List<(CategoriaDespesa, num)> porCategoria;

  factory ListaDespesas.fromJson(Map<String, dynamic> j) => ListaDespesas(
        (j['despesas'] as List).map((e) => Despesa.fromJson(e as Map<String, dynamic>)).toList(),
        numDoJson(j['total']) ?? 0,
        [
          for (final c in (j['porCategoria'] as List).cast<Map<String, dynamic>>())
            (CategoriaDespesa.fromApi(c['categoria'] as String), numDoJson(c['total']) ?? 0),
        ],
      );
}

class DespesasRepository {
  DespesasRepository(this._api);
  final ApiClient _api;

  static const _base = '/api/admin/despesas';

  Future<ListaDespesas> listar(DateTime mes) async {
    final inicio = DateTime(mes.year, mes.month);
    final fim = DateTime(mes.year, mes.month + 1).subtract(const Duration(days: 1));
    return ListaDespesas.fromJson(await _api.get(_base, query: {'inicio': dataParaApi(inicio), 'fim': dataParaApi(fim)})
        as Map<String, dynamic>);
  }

  Future<void> salvar(String? id, Map<String, dynamic> corpo) =>
      id == null ? _api.post(_base, corpo: corpo) : _api.put('$_base/$id', corpo: corpo);

  Future<void> excluir(String id) => _api.delete('$_base/$id');
}

final despesasRepositoryProvider = Provider((ref) => DespesasRepository(ref.watch(apiClientProvider)));

class MesDespesasController extends Notifier<DateTime> {
  @override
  DateTime build() {
    final n = DateTime.now();
    return DateTime(n.year, n.month);
  }

  void avancar(int meses) => state = DateTime(state.year, state.month + meses);
}

final mesDespesasProvider = NotifierProvider<MesDespesasController, DateTime>(MesDespesasController.new);

final despesasProvider = FutureProvider.autoDispose<ListaDespesas>(
  (ref) => ref.watch(despesasRepositoryProvider).listar(ref.watch(mesDespesasProvider)),
);
