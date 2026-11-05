import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

class Fornecedor {
  const Fornecedor({
    required this.id,
    required this.nome,
    this.nomeFantasia,
    this.cnpj,
    this.telefone,
    this.email,
    this.endereco,
    this.observacoes,
    required this.ativo,
  });

  final String id;
  final String nome;
  final String? nomeFantasia;
  final String? cnpj;
  final String? telefone;
  final String? email;
  final String? endereco;
  final String? observacoes;
  final bool ativo;

  String get nomeExibicao => nomeFantasia == null ? nome : '$nomeFantasia ($nome)';

  factory Fornecedor.fromJson(Map<String, dynamic> json) => Fornecedor(
        id: json['id'] as String,
        nome: json['nome'] as String,
        nomeFantasia: json['nomeFantasia'] as String?,
        cnpj: json['cnpj'] as String?,
        telefone: json['telefone'] as String?,
        email: json['email'] as String?,
        endereco: json['endereco'] as String?,
        observacoes: json['observacoes'] as String?,
        ativo: json['ativo'] as bool,
      );
}

class FornecedoresRepository {
  FornecedoresRepository(this._api);
  final ApiClient _api;

  static const _base = '/api/admin/fornecedores';

  Future<PageResponse<Fornecedor>> pesquisar({String? nome, bool? ativo, int pagina = 0, int tamanho = 20}) async {
    final dados = await _api.get(_base, query: {
      'nome': nome,
      'ativo': ativo,
      'page': pagina,
      'size': tamanho,
    });
    return PageResponse.fromJson(dados as Map<String, dynamic>, Fornecedor.fromJson);
  }

  Future<Fornecedor> salvar(String? id, Map<String, dynamic> corpo) async {
    final dados = id == null ? await _api.post(_base, corpo: corpo) : await _api.put('$_base/$id', corpo: corpo);
    return Fornecedor.fromJson(dados as Map<String, dynamic>);
  }

  Future<void> alterarStatus(String id, bool ativo) => _api.patch('$_base/$id/status', corpo: {'ativo': ativo});
}

final fornecedoresRepositoryProvider = Provider((ref) => FornecedoresRepository(ref.watch(apiClientProvider)));

/// Fornecedores ativos para listas de seleção (ex.: fornecedor principal do produto).
final fornecedoresAtivosProvider = FutureProvider.autoDispose<List<Fornecedor>>((ref) async {
  final pagina = await ref.watch(fornecedoresRepositoryProvider).pesquisar(ativo: true, tamanho: 100);
  return pagina.conteudo;
});

class FiltroFornecedores {
  const FiltroFornecedores({this.nome = '', this.pagina = 0});
  final String nome;
  final int pagina;
}

class FiltroFornecedoresController extends Notifier<FiltroFornecedores> {
  @override
  FiltroFornecedores build() => const FiltroFornecedores();

  void pesquisar(String nome) => state = FiltroFornecedores(nome: nome);
  void irParaPagina(int pagina) => state = FiltroFornecedores(nome: state.nome, pagina: pagina);
}

final filtroFornecedoresProvider =
    NotifierProvider<FiltroFornecedoresController, FiltroFornecedores>(FiltroFornecedoresController.new);

final fornecedoresPaginaProvider = FutureProvider.autoDispose<PageResponse<Fornecedor>>((ref) {
  final filtro = ref.watch(filtroFornecedoresProvider);
  return ref.watch(fornecedoresRepositoryProvider).pesquisar(nome: filtro.nome, pagina: filtro.pagina);
});
