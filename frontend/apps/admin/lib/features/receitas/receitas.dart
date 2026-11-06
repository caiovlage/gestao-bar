import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

class ReceitaResumo {
  const ReceitaResumo({required this.id, required this.nome, this.fotoUrl, this.rendimento, this.tempoPreparoMin});

  final String id;
  final String nome;
  final String? fotoUrl;
  final String? rendimento;
  final int? tempoPreparoMin;

  factory ReceitaResumo.fromJson(Map<String, dynamic> j) => ReceitaResumo(
        id: j['id'] as String,
        nome: j['nome'] as String,
        fotoUrl: j['fotoUrl'] as String?,
        rendimento: j['rendimento'] as String?,
        tempoPreparoMin: j['tempoPreparoMin'] as int?,
      );
}

class Receita {
  const Receita({
    required this.id,
    required this.nome,
    this.fotoUrl,
    this.rendimento,
    this.tempoPreparoMin,
    this.ingredientes,
    this.modoPreparo,
    this.atualizadoEm,
  });

  final String id;
  final String nome;
  final String? fotoUrl;
  final String? rendimento;
  final int? tempoPreparoMin;

  /// HTML formatado (já limpo pelo servidor).
  final String? ingredientes;
  final String? modoPreparo;
  final DateTime? atualizadoEm;

  factory Receita.fromJson(Map<String, dynamic> j) => Receita(
        id: j['id'] as String,
        nome: j['nome'] as String,
        fotoUrl: j['fotoUrl'] as String?,
        rendimento: j['rendimento'] as String?,
        tempoPreparoMin: j['tempoPreparoMin'] as int?,
        ingredientes: j['ingredientes'] as String?,
        modoPreparo: j['modoPreparo'] as String?,
        atualizadoEm: dataDoJson(j['atualizadoEm']),
      );
}

class ReceitasRepository {
  ReceitasRepository(this._api);
  final ApiClient _api;

  static const _base = '/api/admin/receitas';

  String? urlImagem(String? caminho) => _api.urlImagem(caminho);

  Future<PageResponse<ReceitaResumo>> pesquisar(String nome) async {
    final dados = await _api.get(_base, query: {'nome': nome, 'size': 100});
    return PageResponse.fromJson(dados as Map<String, dynamic>, ReceitaResumo.fromJson);
  }

  Future<Receita> buscar(String id) async => Receita.fromJson(await _api.get('$_base/$id') as Map<String, dynamic>);

  Future<Receita> salvar(
    String? id, {
    required String nome,
    String? rendimento,
    int? tempoPreparoMin,
    String? ingredientes,
    String? modoPreparo,
  }) async {
    final corpo = {
      'nome': nome,
      'rendimento': rendimento,
      'tempoPreparoMin': tempoPreparoMin,
      'ingredientes': ingredientes,
      'modoPreparo': modoPreparo,
    };
    final dados = id == null ? await _api.post(_base, corpo: corpo) : await _api.put('$_base/$id', corpo: corpo);
    return Receita.fromJson(dados as Map<String, dynamic>);
  }

  Future<void> excluir(String id) => _api.delete('$_base/$id');

  Future<void> enviarFoto(String id, List<int> bytes, String nome) =>
      _api.enviarArquivo('$_base/$id/foto', bytes: bytes, nomeArquivo: nome);

  Future<void> removerFoto(String id) => _api.delete('$_base/$id/foto');
}

final receitasRepositoryProvider = Provider((ref) => ReceitasRepository(ref.watch(apiClientProvider)));

class BuscaReceitasController extends Notifier<String> {
  @override
  String build() => '';

  void mudar(String termo) => state = termo;
}

final buscaReceitasProvider = NotifierProvider<BuscaReceitasController, String>(BuscaReceitasController.new);

final receitasProvider = FutureProvider.autoDispose<PageResponse<ReceitaResumo>>(
  (ref) => ref.watch(receitasRepositoryProvider).pesquisar(ref.watch(buscaReceitasProvider)),
);

final receitaProvider = FutureProvider.autoDispose.family<Receita, String>(
  (ref, id) => ref.watch(receitasRepositoryProvider).buscar(id),
);
