import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'compras.dart';

/// Preços de aquisição do produto nas compras recebidas (mais recentes primeiro).
class HistoricoCustos extends ConsumerWidget {
  const HistoricoCustos({super.key, required this.produtoId, required this.unidadeSigla});

  final String produtoId;
  final String unidadeSigla;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historico = ref.watch(historicoCustosProvider(produtoId));
    return historico.when(
      loading: () => const SizedBox(height: 60, child: Carregando()),
      error: (e, _) => Text(mensagemDeErro(e)),
      data: (lista) => lista.isEmpty
          ? Text('Nenhuma compra recebida ainda. O custo médio é recalculado a cada recebimento.',
              style: TextStyle(color: Colors.grey.shade600))
          : Column(children: [
              for (final h in lista)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        '${formatarData(h.dataHora)} · compra nº ${h.compraNumero}${h.fornecedor == null ? '' : ' · ${h.fornecedor}'}'
                        ' · ${formatarQuantidade(h.quantidade)} $unidadeSigla',
                      ),
                    ),
                    Text('${formatarMoeda(h.custoUnitario)}/$unidadeSigla', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 12),
                    Text('médio ${formatarMoeda(h.custoMedioAnterior)} → ${formatarMoeda(h.custoMedioNovo)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ]),
                ),
            ]),
    );
  }
}
