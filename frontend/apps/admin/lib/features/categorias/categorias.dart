import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

class Categoria {
  const Categoria({
    required this.id,
    required this.nome,
    required this.ordem,
    required this.exibirCardapio,
    required this.ativo,
  });

  final String id;
  final String nome;
  final int ordem;
  final bool exibirCardapio;
  final bool ativo;

  factory Categoria.fromJson(Map<String, dynamic> json) => Categoria(
        id: json['id'] as String,
        nome: json['nome'] as String,
        ordem: json['ordem'] as int,
        exibirCardapio: json['exibirCardapio'] as bool,
        ativo: json['ativo'] as bool,
      );
}

class CategoriasRepository {
  CategoriasRepository(this._api);
  final ApiClient _api;

  static const _base = '/api/admin/categorias';

  Future<List<Categoria>> listar({bool? ativo}) async {
    final dados = await _api.get(_base, query: {'ativo': ativo}) as List;
    return dados.map((e) => Categoria.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Categoria> salvar({String? id, required String nome, required int ordem, required bool exibirCardapio}) async {
    final corpo = {'nome': nome, 'ordem': ordem, 'exibirCardapio': exibirCardapio};
    final dados = id == null ? await _api.post(_base, corpo: corpo) : await _api.put('$_base/$id', corpo: corpo);
    return Categoria.fromJson(dados as Map<String, dynamic>);
  }

  Future<void> alterarStatus(String id, bool ativo) => _api.patch('$_base/$id/status', corpo: {'ativo': ativo});

  Future<void> excluir(String id) => _api.delete('$_base/$id');
}

final categoriasRepositoryProvider = Provider((ref) => CategoriasRepository(ref.watch(apiClientProvider)));

/// Todas as categorias (ativas e inativas), ordenadas.
final categoriasProvider = FutureProvider.autoDispose<List<Categoria>>(
  (ref) => ref.watch(categoriasRepositoryProvider).listar(),
);
