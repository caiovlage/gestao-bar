import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'caixa.dart';

void _atualizar(WidgetRef ref) {
  ref.invalidate(caixaAtualProvider);
  ref.invalidate(historicoCaixasProvider);
}

/// Abre o caixa (saldo inicial em dinheiro). Retorna true se abriu.
Future<bool> abrirCaixa(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(context: context, builder: (_) => const _AbrirCaixaDialog());
  if (ok == true) {
    _atualizar(ref);
    if (context.mounted) mostrarSucesso(context, 'Caixa aberto.');
  }
  return ok == true;
}

Future<void> movimentarCaixa(BuildContext context, WidgetRef ref, {required bool suprimento}) async {
  final ok = await showDialog<bool>(context: context, builder: (_) => _MovimentoDialog(suprimento: suprimento));
  if (ok == true) {
    _atualizar(ref);
    if (context.mounted) mostrarSucesso(context, suprimento ? 'Suprimento registrado.' : 'Retirada registrada.');
  }
}

Future<void> fecharCaixa(BuildContext context, WidgetRef ref, Caixa caixa) async {
  final fechado = await showDialog<Caixa>(context: context, builder: (_) => _FecharDialog(caixa: caixa));
  if (fechado != null) {
    _atualizar(ref);
    if (context.mounted) {
      final dif = fechado.diferenca ?? 0;
      mostrarSucesso(
          context,
          dif == 0
              ? 'Caixa fechado sem diferença.'
              : 'Caixa fechado com diferença de ${formatarMoeda(dif)} (${dif > 0 ? 'sobra' : 'falta'}).');
    }
  }
}

class _AbrirCaixaDialog extends ConsumerStatefulWidget {
  const _AbrirCaixaDialog();

  @override
  ConsumerState<_AbrirCaixaDialog> createState() => _AbrirCaixaDialogState();
}

class _AbrirCaixaDialogState extends ConsumerState<_AbrirCaixaDialog> {
  final _saldo = TextEditingController(text: '0');
  final _obs = TextEditingController();
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _saldo.dispose();
    _obs.dispose();
    super.dispose();
  }

  Future<void> _abrir() async {
    final saldo = lerDecimal(_saldo.text);
    if (saldo == null || saldo < 0) {
      setState(() => _erro = 'Informe o saldo inicial (dinheiro na gaveta).');
      return;
    }
    setState(() => _salvando = true);
    try {
      await ref.read(caixaRepositoryProvider).abrir(saldo, _obs.text.trim().isEmpty ? null : _obs.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _erro = mensagemDeErro(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Abrir caixa'),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _saldo,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Saldo inicial em dinheiro',
              prefixText: r'R$ ',
              helperText: 'Troco disponível na gaveta no início do turno',
            ),
            onSubmitted: (_) => _abrir(),
          ),
          const SizedBox(height: 12),
          TextField(controller: _obs, maxLength: 500, decoration: const InputDecoration(labelText: 'Observação')),
          if (_erro != null) Text(_erro!, style: const TextStyle(color: AppCores.perigo)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: _salvando ? null : _abrir, child: const Text('Abrir caixa')),
      ],
    );
  }
}

class _MovimentoDialog extends ConsumerStatefulWidget {
  const _MovimentoDialog({required this.suprimento});

  final bool suprimento;

  @override
  ConsumerState<_MovimentoDialog> createState() => _MovimentoDialogState();
}

class _MovimentoDialogState extends ConsumerState<_MovimentoDialog> {
  final _valor = TextEditingController();
  final _motivo = TextEditingController();
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _valor.dispose();
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final valor = lerDecimal(_valor.text);
    if (valor == null || valor <= 0 || _motivo.text.trim().isEmpty) {
      setState(() => _erro = 'Informe o valor e o motivo.');
      return;
    }
    setState(() => _salvando = true);
    try {
      await ref
          .read(caixaRepositoryProvider)
          .movimentar(suprimento: widget.suprimento, valor: valor, motivo: _motivo.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _erro = mensagemDeErro(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.suprimento ? 'Suprimento (entrada de dinheiro)' : 'Retirada (sangria)'),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _valor,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Valor', prefixText: r'R$ '),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _motivo,
            maxLength: 300,
            decoration: InputDecoration(
              labelText: 'Motivo *',
              hintText: widget.suprimento ? 'Ex.: reforço de troco' : 'Ex.: depósito, pagamento de fornecedor',
            ),
            onSubmitted: (_) => _salvar(),
          ),
          if (_erro != null) Text(_erro!, style: const TextStyle(color: AppCores.perigo)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: _salvando ? null : _salvar, child: const Text('Registrar')),
      ],
    );
  }
}

class _FecharDialog extends ConsumerStatefulWidget {
  const _FecharDialog({required this.caixa});

  final Caixa caixa;

  @override
  ConsumerState<_FecharDialog> createState() => _FecharDialogState();
}

class _FecharDialogState extends ConsumerState<_FecharDialog> {
  final _contado = TextEditingController();
  final _obs = TextEditingController();
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _contado.dispose();
    _obs.dispose();
    super.dispose();
  }

  Future<void> _fechar() async {
    final contado = lerDecimal(_contado.text);
    if (contado == null || contado < 0) {
      setState(() => _erro = 'Informe o dinheiro contado na gaveta.');
      return;
    }
    setState(() => _salvando = true);
    try {
      final caixa = await ref
          .read(caixaRepositoryProvider)
          .fechar(contado, _obs.text.trim().isEmpty ? null : _obs.text.trim());
      if (mounted) Navigator.pop(context, caixa);
    } catch (e) {
      setState(() => _erro = mensagemDeErro(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.caixa.totais;
    final contado = lerDecimal(_contado.text);
    final diferenca = contado == null ? null : contado - t.saldoEsperado;
    return AlertDialog(
      title: const Text('Fechar caixa'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _linha('Vendas (${t.quantidadeVendas})', formatarMoeda(t.totalVendas)),
          _linha('  em dinheiro', formatarMoeda(t.dinheiro)),
          _linha('  PIX', formatarMoeda(t.pix)),
          _linha('  cartões', formatarMoeda(t.cartaoDebito + t.cartaoCredito)),
          _linha('  outros', formatarMoeda(t.outros)),
          const Divider(height: 20),
          _linha('Dinheiro esperado na gaveta', formatarMoeda(t.saldoEsperado), destaque: true),
          Text(
            'Saldo inicial ${formatarMoeda(widget.caixa.saldoInicial)} + dinheiro ${formatarMoeda(t.dinheiro)} '
            '+ suprimentos ${formatarMoeda(t.suprimentos)} − retiradas ${formatarMoeda(t.retiradas)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contado,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Dinheiro contado na gaveta *', prefixText: r'R$ '),
            onChanged: (_) => setState(() {}),
          ),
          if (diferenca != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                diferenca == 0
                    ? 'Sem diferença.'
                    : 'Diferença: ${formatarMoeda(diferenca)} (${diferenca > 0 ? 'sobra' : 'falta'})',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: diferenca == 0 ? AppCores.sucesso : AppCores.perigo,
                ),
              ),
            ),
          const SizedBox(height: 12),
          TextField(controller: _obs, maxLength: 500, decoration: const InputDecoration(labelText: 'Observação')),
          if (_erro != null) Text(_erro!, style: const TextStyle(color: AppCores.perigo)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _salvando ? null : _fechar, child: const Text('Fechar caixa')),
      ],
    );
  }

  Widget _linha(String rotulo, String valor, {bool destaque = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(rotulo, style: TextStyle(fontWeight: destaque ? FontWeight.w700 : null))),
          Text(valor, style: TextStyle(fontWeight: destaque ? FontWeight.w800 : FontWeight.w600)),
        ]),
      );
}
