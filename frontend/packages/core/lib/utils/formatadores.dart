import 'package:intl/intl.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
final _quantidade = NumberFormat('#,##0.###', 'pt_BR');
final _percentual = NumberFormat('#,##0.0', 'pt_BR');
final _entrada = NumberFormat('0.######', 'pt_BR');

/// R$ 1.234,56
String formatarMoeda(num? valor) => valor == null ? '—' : _moeda.format(valor);

/// 1.234,5 (sem zeros desnecessários)
String formatarQuantidade(num? valor) =>
    valor == null ? '—' : _quantidade.format(valor);

/// 56,3%
String formatarPercentual(num? valor) =>
    valor == null ? '—' : '${_percentual.format(valor)}%';

/// Valor para preencher campos de texto editáveis (vírgula decimal, sem milhar).
String formatarParaEdicao(num? valor) =>
    valor == null ? '' : _entrada.format(valor);

/// Lê números digitados com vírgula ou ponto ("8,50", "8.50", "1.234,5").
num? lerDecimal(String? texto) {
  if (texto == null) return null;
  var t = texto.trim().replaceAll(' ', '');
  if (t.isEmpty) return null;
  if (t.contains(',')) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  }
  return num.tryParse(t);
}

final _dataHora = DateFormat('dd/MM/yyyy HH:mm');
final _data = DateFormat('dd/MM/yyyy');
final _dataApi = DateFormat('yyyy-MM-dd');

/// 06/11/2026 14:35 (no fuso do dispositivo)
String formatarDataHora(DateTime? valor) => valor == null ? '—' : _dataHora.format(valor.toLocal());

/// 06/11/2026
String formatarData(DateTime? valor) => valor == null ? '—' : _data.format(valor.toLocal());

/// 2026-11-06 (parâmetros de data da API)
String dataParaApi(DateTime valor) => _dataApi.format(valor);

/// Lê datas ISO-8601 da API. O backend envia nanossegundos (9 casas); mantém só 6.
DateTime? dataDoJson(Object? valor) {
  if (valor == null) return null;
  final texto = '$valor'.replaceFirstMapped(RegExp(r'(\.\d{6})\d+'), (m) => m[1]!);
  return DateTime.tryParse(texto);
}

/// Converte valores numéricos vindos do JSON (int, double ou string).
num? numDoJson(Object? valor) {
  if (valor == null) return null;
  if (valor is num) return valor;
  return num.tryParse('$valor');
}
