import 'package:dio/dio.dart';

/// Erro retornado pela API no formato RFC 7807 (ProblemDetail), já traduzido para o app.
class ApiException implements Exception {
  ApiException({
    required this.codigo,
    required this.mensagem,
    this.status,
    this.campos = const {},
  });

  /// Código estável de negócio (ex.: ESTOQUE_INSUFICIENTE, DADOS_INVALIDOS).
  final String codigo;
  final String mensagem;
  final int? status;

  /// Erros de validação por campo (nome do campo → mensagem).
  final Map<String, String> campos;

  bool get naoAutenticado => status == 401;

  factory ApiException.fromDio(DioException e) {
    final resposta = e.response;
    if (resposta == null) {
      return ApiException(
        codigo: 'SEM_CONEXAO',
        mensagem: 'Não foi possível conectar ao servidor. Verifique a conexão.',
      );
    }
    final dados = resposta.data;
    if (dados is Map) {
      final campos = <String, String>{};
      final brutos = dados['campos'];
      if (brutos is Map) {
        brutos.forEach((k, v) => campos['$k'] = '$v');
      }
      return ApiException(
        codigo: '${dados['codigo'] ?? 'ERRO'}',
        mensagem: '${dados['detail'] ?? 'Erro ao processar a requisição.'}',
        status: resposta.statusCode,
        campos: campos,
      );
    }
    return ApiException(
      codigo: 'ERRO_HTTP',
      mensagem: 'Erro ${resposta.statusCode} ao processar a requisição.',
      status: resposta.statusCode,
    );
  }

  @override
  String toString() => mensagem;
}

/// Mensagem amigável para qualquer erro exibido na interface.
String mensagemDeErro(Object erro) {
  if (erro is String) return erro;
  if (erro is ApiException) return erro.mensagem;
  if (erro is DioException) return ApiException.fromDio(erro).mensagem;
  // Erro fora da API: registra no console (F12 no navegador) para diagnóstico.
  // ignore: avoid_print
  print('Erro inesperado (${erro.runtimeType}): $erro');
  return 'Ocorreu um erro inesperado.';
}
