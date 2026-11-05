import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Etiqueta colorida compacta (status, alertas).
class Etiqueta extends StatelessWidget {
  const Etiqueta(this.texto, {super.key, required this.cor, this.icone});

  factory Etiqueta.status(bool ativo) => ativo
      ? const Etiqueta('Ativo', cor: AppCores.sucesso)
      : Etiqueta('Inativo', cor: Colors.grey.shade600);

  final String texto;
  final Color cor;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[Icon(icone, size: 14, color: cor), const SizedBox(width: 4)],
          Text(texto, style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
