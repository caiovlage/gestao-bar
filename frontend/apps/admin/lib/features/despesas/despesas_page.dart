import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../fornecedores/fornecedores.dart';
import '../relatorios/relatorios.dart';
import 'despesas.dart';

const _meses = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro',
  'novembro', 'dezembro'];

class DespesasPage extends ConsumerWidget {
  const DespesasPage({super.key});

  Future<void> _abrir(BuildContext context, WidgetRef ref, {Despesa? despesa}) async {
    final salvou = await showDialog<bool>(context: context, builder: (_) => _DespesaDialog(despesa: despesa));
    if (salvou == true) {
      ref.invalidate(despesasProvider);
      ref.invalidate(painelRelatorioProvider);
      ref.invalidate(painelDashboardProvider);
      if (context.mounted) mostrarSucesso(context, 'Despesa salva.');
    }
  }

  Future<void> _excluir(BuildContext context, WidgetRef ref, Despesa d) async {
    if (!await confirmar(context, titulo: 'Excluir despesa', mensagem: 'Excluir "${d.descricao}"?', acao: 'Excluir', perigoso: true)) {
      return;
    }
    try {
      await ref.read(despesasRepositoryProvider).excluir(d.id);
      ref.invalidate(despesasProvider);
      ref.invalidate(painelRelatorioProvider);
    } catch (e) {
      if (context.mounted) mostrarErro(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesDespesasProvider);
    final controle = ref.read(mesDespesasProvider.notifier);
    final lista = ref.watch(despesasProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CabecalhoPagina(
          titulo: 'Despesas',
          subtitulo: 'Custos operacionais usados no cálculo do lucro líquido',
          acoes: [
            FilledButton.icon(onPressed: () => _abrir(context, ref), icon: const Icon(Icons.add), label: const Text('Nova despesa')),
          ],
        ),
        Row(children: [
          IconButton.outlined(tooltip: 'Mês anterior', onPressed: () => controle.avancar(-1), icon: const Icon(Icons.chevron_left)),
          const SizedBox(width: 12),
          Text('${_meses[mes.month - 1]} de ${mes.year}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(width: 12),
          IconButton.outlined(tooltip: 'Próximo mês', onPressed: () => controle.avancar(1), icon: const Icon(Icons.chevron_right)),
        ]),
        const SizedBox(height: 16),
        lista.when(
          loading: () => const Card(child: Carregando()),
          error: (e, _) => Card(child: ErroView(mensagem: mensagemDeErro(e), aoTentarNovamente: () => ref.invalidate(despesasProvider))),
          data: (l) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('Total: ${formatarMoeda(l.total)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              for (final (c, v) in l.porCategoria) Chip(avatar: Icon(c.icone, size: 18), label: Text('${c.rotulo}: ${formatarMoeda(v)}')),
            ]),
            const SizedBox(height: 12),
            Card(
              child: l.despesas.isEmpty
                  ? const EstadoVazio(icone: Icons.request_quote_outlined, titulo: 'Nenhuma despesa neste mês')
                  : Column(children: [
                      for (final (i, d) in l.despesas.indexed) ...[
                        if (i > 0) const Divider(),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          onTap: () => _abrir(context, ref, despesa: d),
                          leading: CircleAvatar(child: Icon(d.categoria.icone)),
                          title: Text(d.descricao, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text([
                            DateFormat('dd/MM/yyyy').format(d.data),
                            d.categoria.rotulo,
                            if (d.fornecedor != null) d.fornecedor!,
                          ].join(' · ')),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(formatarMoeda(d.valor), style: const TextStyle(fontWeight: FontWeight.w800)),
                            IconButton(tooltip: 'Excluir', onPressed: () => _excluir(context, ref, d), icon: const Icon(Icons.delete_outline)),
                          ]),
                        ),
                      ],
                    ]),
            ),
          ]),
        ),
      ],
    );
  }
}

class _DespesaDialog extends ConsumerStatefulWidget {
  const _DespesaDialog({this.despesa});

  final Despesa? despesa;

  @override
  ConsumerState<_DespesaDialog> createState() => _DespesaDialogState();
}

class _DespesaDialogState extends ConsumerState<_DespesaDialog> {
  late final _descricao = TextEditingController(text: widget.despesa?.descricao);
  late final _valor = TextEditingController(text: formatarParaEdicao(widget.despesa?.valor));
  late final _obs = TextEditingController(text: widget.despesa?.observacao);
  late CategoriaDespesa _categoria = widget.despesa?.categoria ?? CategoriaDespesa.outros;
  late DateTime _data = widget.despesa?.data ?? DateTime.now();
  late String? _fornecedorId = widget.despesa?.fornecedorId;
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _descricao.dispose();
    _valor.dispose();
    _obs.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final valor = lerDecimal(_valor.text);
    if (_descricao.text.trim().isEmpty || valor == null || valor <= 0) {
      setState(() => _erro = 'Informe a descrição e o valor.');
      return;
    }
    setState(() => _salvando = true);
    try {
      await ref.read(despesasRepositoryProvider).salvar(widget.despesa?.id, {
        'descricao': _descricao.text.trim(),
        'categoria': _categoria.api,
        'valor': valor,
        'data': dataParaApi(_data),
        'fornecedorId': _fornecedorId,
        'observacao': _obs.text.trim().isEmpty ? null : _obs.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _erro = mensagemDeErro(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fornecedores = ref.watch(fornecedoresAtivosProvider).value ?? const <Fornecedor>[];
    return AlertDialog(
      title: Text(widget.despesa == null ? 'Nova despesa' : 'Editar despesa'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: _descricao,
              autofocus: true,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Descrição *', hintText: 'Ex.: conta de luz de outubro'),
            ),
            DropdownButtonFormField<CategoriaDespesa>(
              initialValue: _categoria,
              decoration: const InputDecoration(labelText: 'Categoria'),
              items: [for (final c in CategoriaDespesa.values) DropdownMenuItem(value: c, child: Text(c.rotulo))],
              onChanged: (c) => setState(() => _categoria = c!),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _valor,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Valor *', prefixText: r'R$ '),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text(DateFormat('dd/MM/yyyy').format(_data)),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _data,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setState(() => _data = d);
                  },
                ),
              ),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: fornecedores.any((f) => f.id == _fornecedorId) ? _fornecedorId : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Fornecedor (opcional)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Nenhum')),
                for (final f in fornecedores) DropdownMenuItem(value: f.id, child: Text(f.nomeExibicao, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _fornecedorId = v),
            ),
            const SizedBox(height: 12),
            TextField(controller: _obs, maxLength: 500, decoration: const InputDecoration(labelText: 'Observação')),
            if (_erro != null) Text(_erro!, style: const TextStyle(color: AppCores.perigo)),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: _salvando ? null : _salvar, child: const Text('Salvar')),
      ],
    );
  }
}
