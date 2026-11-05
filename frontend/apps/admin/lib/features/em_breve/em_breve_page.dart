import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../app/menu.dart';

/// Página exibida para módulos planejados em etapas futuras.
class EmBrevePage extends StatelessWidget {
  const EmBrevePage({super.key, required this.item});

  final ItemMenu item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CabecalhoPagina(titulo: item.rotulo),
        Card(
          child: EstadoVazio(
            icone: item.icone,
            titulo: 'Disponível na Etapa ${item.etapa}',
            descricao: item.descricao,
          ),
        ),
      ],
    );
  }
}
