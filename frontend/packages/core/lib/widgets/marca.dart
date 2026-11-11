import 'package:flutter/material.dart';

/// Versões do logo "Entre Nós" (arte original, fundo transparente).
enum VersaoMarca {
  /// Símbolo + nome + "Bar de Piscina & Bistrô" + frase.
  completa('assets/marca/logo-entre-nos.png', 695 / 376),

  /// Símbolo + nome.
  compacta('assets/marca/logo-entre-nos-compacta.png', 695 / 275),

  /// Só o símbolo (sol e montanhas).
  simbolo('assets/marca/simbolo-entre-nos.png', 411 / 120);

  const VersaoMarca(this.caminho, this.proporcao);
  final String caminho;

  /// largura ÷ altura
  final double proporcao;
}

/// Logo da marca. Sem [cor], usa as cores originais (verde e dourado); com [cor], pinta tudo
/// de uma cor só (ex.: dourado sobre o verde do menu, como na capa do cardápio).
class Marca extends StatelessWidget {
  const Marca({super.key, this.versao = VersaoMarca.completa, this.largura, this.altura, this.cor});

  final VersaoMarca versao;
  final double? largura;
  final double? altura;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final w = largura ?? (altura != null ? altura! * versao.proporcao : null);
    final h = altura ?? (largura != null ? largura! / versao.proporcao : null);
    return Image.asset(
      versao.caminho,
      package: 'core',
      width: w,
      height: h,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      color: cor,
      colorBlendMode: cor == null ? null : BlendMode.srcIn,
      semanticLabel: 'Entre Nós',
    );
  }
}
