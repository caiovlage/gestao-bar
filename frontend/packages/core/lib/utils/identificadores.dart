import 'dart:math';

final _aleatorio = Random.secure();

/// UUID versão 4 (aleatório), ex.: chave de idempotência de uma venda.
String gerarUuid() {
  final b = List<int>.generate(16, (_) => _aleatorio.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // versão 4
  b[8] = (b[8] & 0x3f) | 0x80; // variante RFC 4122
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}
