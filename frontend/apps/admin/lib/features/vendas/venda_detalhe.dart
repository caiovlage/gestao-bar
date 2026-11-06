import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../caixa/caixa.dart';
import '../estoque/estoque.dart';
import 'vendas.dart';

/// Mostra o comprovante interno da venda (texto), com opção de copiar.
Future<void> mostrarComprovante(BuildContext context, Venda venda) {
  final texto = comprovante(venda);
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Comprovante · venda nº ${venda.numero}'),
      content: Container(
        width: 380,
        padding: const EdgeInsets.all(12),
        color: const Color(0xFFFFFDF5),
        child: SelectableText(texto, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.35)),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: texto));
            if (context.mounted) mostrarSucesso(context, 'Comprovante copiado.');
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copiar'),
        ),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
      ],
    ),
  );
}

/// Detalhe de uma venda, com comprovante e cancelamento.
Future<void> abrirDetalheVenda(BuildContext context, WidgetRef ref, String vendaId) =>
    showDialog<void>(context: context, builder: (_) => _DetalheVendaDialog(vendaId: vendaId));

final _vendaProvider = FutureProvider.autoDispose.family<Venda, String>(
  (ref, id) => ref.watch(vendasRepositoryProvider).buscar(id),
);

class _DetalheVendaDialog extends ConsumerWidget {
  const _DetalheVendaDialog({required this.vendaId});

  final String vendaId;

  Future<void> _cancelar(BuildContext context, WidgetRef ref, Venda v) async {
    final motivo = await showDialog<String>(context: context, builder: (_) => const _MotivoDialog());
    if (motivo == null) return;
    try {
      await ref.read(vendasRepositoryProvider).cancelar(v.id, motivo);
      ref.invalidate(_vendaProvider(v.id));
      ref.invalidate(vendasProvider);
      ref.invalidate(caixaAtualProvider);
      ref.invalidate(catalogoPdvProvider);
      ref.invalidate(posicaoEstoqueProvider);
      if (context.mounted) mostrarSucesso(context, 'Venda nº ${v.numero} cancelada; estoque estornado.');
    } catch (e) {
      if (context.mounted) mostrarErro(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venda = ref.watch(_vendaProvider(vendaId));
    return AlertDialog(
      title: Text(venda.value == null ? 'Venda' : 'Venda nº ${venda.value!.numero}'),
      content: SizedBox(
        width: 520,
        child: venda.when(
          loading: () => const SizedBox(height: 160, child: Carregando()),
          error: (e, _) => ErroView(mensagem: mensagemDeErro(e)),
          data: (v) => SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Wrap(spacing: 8, runSpacing: 6, children: [
                Text(formatarDataHora(v.dataHora)),
                Etiqueta(v.formaPagamento.rotulo, cor: AppCores.grafite, icone: v.formaPagamento.icone),
                if (v.cancelada) const Etiqueta('Cancelada', cor: AppCores.perigo),
              ]),
              const SizedBox(height: 12),
              for (final i in v.itens)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(child: Text('${formatarQuantidade(i.quantidade)} × ${i.produtoNome}')),
                    Text(formatarMoeda(i.total)),
                  ]),
                ),
              const Divider(height: 20),
              _linha('Subtotal', formatarMoeda(v.subtotal)),
              if (v.desconto > 0) _linha('Desconto', '−${formatarMoeda(v.desconto)}'),
              _linha('Total', formatarMoeda(v.total), destaque: true),
              if (v.troco != null && v.troco! > 0)
                _linha('Recebido / troco', '${formatarMoeda(v.valorRecebido)} / ${formatarMoeda(v.troco)}'),
              const Divider(height: 20),
              _linha('Custo dos produtos', formatarMoeda(v.custoTotal)),
              _linha('Lucro bruto', '${formatarMoeda(v.lucroBruto)}  (${formatarPercentual(v.margemPercentual)})'),
              if (v.cancelada) ...[
                const Divider(height: 20),
                Text('Cancelada em ${formatarDataHora(v.canceladaEm)}',
                    style: const TextStyle(color: AppCores.perigo, fontWeight: FontWeight.w600)),
                Text('Motivo: ${v.motivoCancelamento ?? '—'}'),
              ],
            ]),
          ),
        ),
      ),
      actions: [
        if (venda.value != null) ...[
          TextButton.icon(
            onPressed: () => mostrarComprovante(context, venda.value!),
            icon: const Icon(Icons.receipt_long),
            label: const Text('Comprovante'),
          ),
          if (!venda.value!.cancelada)
            TextButton(
              onPressed: () => _cancelar(context, ref, venda.value!),
              style: TextButton.styleFrom(foregroundColor: AppCores.perigo),
              child: const Text('Cancelar venda'),
            ),
        ],
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
      ],
    );
  }

  Widget _linha(String rotulo, String valor, {bool destaque = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(rotulo, style: TextStyle(fontWeight: destaque ? FontWeight.w700 : null))),
          Text(valor, style: TextStyle(fontWeight: destaque ? FontWeight.w800 : FontWeight.w600, fontSize: destaque ? 16 : null)),
        ]),
      );
}

class _MotivoDialog extends StatefulWidget {
  const _MotivoDialog();

  @override
  State<_MotivoDialog> createState() => _MotivoDialogState();
}

class _MotivoDialogState extends State<_MotivoDialog> {
  final _motivo = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancelar venda'),
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('A venda continua no histórico como cancelada e o estoque é estornado.'),
          const SizedBox(height: 12),
          TextField(
            controller: _motivo,
            autofocus: true,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Justificativa *', hintText: 'Ex.: lançada em duplicidade'),
            onChanged: (_) => setState(() {}),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Voltar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppCores.perigo, foregroundColor: Colors.white),
          onPressed: _motivo.text.trim().isEmpty ? null : () => Navigator.pop(context, _motivo.text.trim()),
          child: const Text('Cancelar venda'),
        ),
      ],
    );
  }
}
