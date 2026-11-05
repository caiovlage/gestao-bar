import 'package:core/core.dart';
import 'package:flutter/material.dart';

/// Rodapé de paginação: "12 registros · Página 1 de 3  ‹ ›".
class Paginacao extends StatelessWidget {
  const Paginacao({super.key, required this.pagina, required this.aoMudar});

  final PageResponse<Object?> pagina;
  final ValueChanged<int> aoMudar;

  @override
  Widget build(BuildContext context) {
    final p = pagina;
    final total = p.totalPaginas == 0 ? 1 : p.totalPaginas;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${p.totalElementos} registro${p.totalElementos == 1 ? '' : 's'} · Página ${p.pagina + 1} de $total',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          IconButton(
            tooltip: 'Página anterior',
            onPressed: p.temAnterior ? () => aoMudar(p.pagina - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Próxima página',
            onPressed: p.temProxima ? () => aoMudar(p.pagina + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
