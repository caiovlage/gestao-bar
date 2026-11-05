import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Cliente HTTP fino sobre o Dio: injeta o token JWT, converte erros em [ApiException]
/// e avisa o app quando a sessão expira (HTTP 401).
class ApiClient {
  ApiClient({
    required String baseUrl,
    Future<String?> Function()? lerToken,
    void Function()? aoNaoAutenticado,
  }) : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
            contentType: Headers.jsonContentType,
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await lerToken?.call();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (erro, handler) {
          final ehLogin = erro.requestOptions.path.endsWith('/auth/login');
          if (erro.response?.statusCode == 401 && !ehLogin) {
            aoNaoAutenticado?.call();
          }
          handler.next(erro);
        },
      ),
    );
  }

  final Dio dio;

  /// URL base da API, usada também para montar URLs de imagens.
  String get baseUrl => dio.options.baseUrl;

  /// Converte caminhos relativos de imagem (/api/public/imagens/...) em URL absoluta.
  String? urlImagem(String? caminho) {
    if (caminho == null || caminho.isEmpty) return null;
    if (caminho.startsWith('http')) return caminho;
    return '$baseUrl$caminho';
  }

  Future<dynamic> get(String caminho, {Map<String, dynamic>? query}) =>
      _executar(() => dio.get(caminho, queryParameters: _semNulos(query)));

  Future<dynamic> post(String caminho, {Object? corpo}) =>
      _executar(() => dio.post(caminho, data: corpo));

  Future<dynamic> put(String caminho, {Object? corpo}) =>
      _executar(() => dio.put(caminho, data: corpo));

  Future<dynamic> patch(String caminho, {Object? corpo}) =>
      _executar(() => dio.patch(caminho, data: corpo));

  Future<dynamic> delete(String caminho) => _executar(() => dio.delete(caminho));

  /// Envio de arquivo (multipart). [campo] é o nome do parâmetro esperado pela API.
  Future<dynamic> enviarArquivo(
    String caminho, {
    required List<int> bytes,
    required String nomeArquivo,
    String campo = 'arquivo',
  }) =>
      _executar(
        () => dio.post(
          caminho,
          data: FormData.fromMap({
            campo: MultipartFile.fromBytes(bytes, filename: nomeArquivo),
          }),
        ),
      );

  Future<dynamic> _executar(Future<Response<dynamic>> Function() chamada) async {
    try {
      final resposta = await chamada();
      return resposta.data;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  static Map<String, dynamic>? _semNulos(Map<String, dynamic>? query) {
    if (query == null) return null;
    return Map.fromEntries(
      query.entries.where((e) => e.value != null && '${e.value}'.isNotEmpty),
    );
  }
}
