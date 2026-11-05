import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

enum Grandeza {
  massa('MASSA', 'Massa'),
  volume('VOLUME', 'Volume'),
  unidade('UNIDADE', 'Unidade'),
  embalagem('EMBALAGEM', 'Embalagem');

  const Grandeza(this.api, this.rotulo);
  final String api;
  final String rotulo;

  static Grandeza fromApi(String valor) => values.firstWhere((g) => g.api == valor);
}

class UnidadeMedida {
  const UnidadeMedida({
    required this.id,
    required this.sigla,
    required this.nome,
    required this.grandeza,
    required this.fatorBase,
    required this.unidadeBase,
  });

  final String id;
  final String sigla;
  final String nome;
  final Grandeza grandeza;
  final num? fatorBase;
  final bool unidadeBase;

  bool get embalagem => grandeza == Grandeza.embalagem;
  String get descricao => '$nome ($sigla)';

  factory UnidadeMedida.fromJson(Map<String, dynamic> json) => UnidadeMedida(
        id: json['id'] as String,
        sigla: json['sigla'] as String,
        nome: json['nome'] as String,
        grandeza: Grandeza.fromApi(json['grandeza'] as String),
        fatorBase: numDoJson(json['fatorBase']),
        unidadeBase: json['unidadeBase'] as bool,
      );
}

class UnidadesRepository {
  UnidadesRepository(this._api);
  final ApiClient _api;

  Future<List<UnidadeMedida>> listar() async {
    final dados = await _api.get('/api/admin/unidades') as List;
    return dados.map((e) => UnidadeMedida.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<UnidadeMedida> criar({
    required String sigla,
    required String nome,
    required Grandeza grandeza,
    num? fatorBase,
  }) async {
    final dados = await _api.post('/api/admin/unidades', corpo: {
      'sigla': sigla,
      'nome': nome,
      'grandeza': grandeza.api,
      'fatorBase': fatorBase,
    });
    return UnidadeMedida.fromJson(dados as Map<String, dynamic>);
  }
}

final unidadesRepositoryProvider = Provider((ref) => UnidadesRepository(ref.watch(apiClientProvider)));

final unidadesProvider = FutureProvider.autoDispose<List<UnidadeMedida>>(
  (ref) => ref.watch(unidadesRepositoryProvider).listar(),
);
