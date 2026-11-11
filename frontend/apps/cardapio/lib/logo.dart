import 'package:flutter/material.dart';

import 'tema.dart';

/// Símbolo da marca: sol dourado nascendo atrás da linha das montanhas (Pão de Açúcar).
class SimboloMarca extends StatelessWidget {
  const SimboloMarca({super.key, this.largura = 120, this.corMontanha = Paleta.verde, this.corSol = Paleta.douradoSuave});

  final double largura;
  final Color corMontanha;
  final Color corSol;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(largura, largura * 0.42),
      painter: _SimboloPainter(corMontanha: corMontanha, corSol: corSol),
    );
  }
}

class _SimboloPainter extends CustomPainter {
  _SimboloPainter({required this.corMontanha, required this.corSol});

  final Color corMontanha;
  final Color corSol;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final traco = w * 0.022;

    // Sol: meio arco dourado
    final sol = Paint()
      ..color = corSol
      ..style = PaintingStyle.stroke
      ..strokeWidth = traco * 1.1
      ..strokeCap = StrokeCap.round;
    final centro = Offset(w * 0.40, h * 0.80);
    canvas.drawArc(Rect.fromCircle(center: centro, radius: w * 0.17), 3.14159 * 1.02, 3.14159 * 0.96, false, sol);

    // Montanhas: uma linha contínua, suave, com dois picos à direita
    final montanha = Paint()
      ..color = corMontanha
      ..style = PaintingStyle.stroke
      ..strokeWidth = traco
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final p = Path()
      ..moveTo(w * 0.02, h * 0.98)
      ..quadraticBezierTo(w * 0.22, h * 0.70, w * 0.42, h * 0.72)
      ..quadraticBezierTo(w * 0.52, h * 0.73, w * 0.58, h * 0.52)
      ..quadraticBezierTo(w * 0.62, h * 0.38, w * 0.66, h * 0.50)
      ..quadraticBezierTo(w * 0.70, h * 0.60, w * 0.74, h * 0.34)
      ..quadraticBezierTo(w * 0.78, h * 0.08, w * 0.84, h * 0.36)
      ..quadraticBezierTo(w * 0.90, h * 0.66, w * 0.99, h * 0.72);
    canvas.drawPath(p, montanha);
    // segunda colina, à esquerda, mais baixa
    final colina = Path()
      ..moveTo(w * 0.20, h * 0.99)
      ..quadraticBezierTo(w * 0.40, h * 0.82, w * 0.62, h * 0.93);
    canvas.drawPath(colina, montanha..strokeWidth = traco * 0.8);
  }

  @override
  bool shouldRepaint(covariant _SimboloPainter old) => old.corMontanha != corMontanha || old.corSol != corSol;
}

/// Linha fina dourada com o texto no meio (ex.: — alma carioca, coração de bistrô —).
class FraseComLinhas extends StatelessWidget {
  const FraseComLinhas(this.texto, {super.key, this.tamanho = 16});

  final String texto;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    Widget linha() => Container(width: 36, height: 1, color: Paleta.douradoSuave);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      linha(),
      Flexible(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(texto,
              textAlign: TextAlign.center,
              style: serifa(tamanho, peso: FontWeight.w400, cor: Paleta.verde, italico: true)),
        ),
      ),
      linha(),
    ]);
  }
}
