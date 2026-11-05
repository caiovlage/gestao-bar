/// Página de resultados no formato padronizado da API.
class PageResponse<T> {
  const PageResponse({
    required this.conteudo,
    required this.pagina,
    required this.tamanho,
    required this.totalElementos,
    required this.totalPaginas,
  });

  final List<T> conteudo;
  final int pagina;
  final int tamanho;
  final int totalElementos;
  final int totalPaginas;

  bool get temAnterior => pagina > 0;
  bool get temProxima => pagina + 1 < totalPaginas;

  factory PageResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) item,
  ) {
    return PageResponse(
      conteudo: (json['conteudo'] as List)
          .map((e) => item(e as Map<String, dynamic>))
          .toList(),
      pagina: json['pagina'] as int,
      tamanho: json['tamanho'] as int,
      totalElementos: json['totalElementos'] as int,
      totalPaginas: json['totalPaginas'] as int,
    );
  }
}
