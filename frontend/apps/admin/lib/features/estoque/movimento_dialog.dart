import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../produtos/produtos.dart';
import '../unidades/unidades.dart';
import 'estoque.dart';

enum ModoMovimento { entrada, saida, ajuste }

/// Abre o diálogo de movimentação e, se registrada, atualiza as listas e avisa o usuário.
Future<void> abrirMovimento(
  BuildContext context,
  WidgetRef ref, {
  required String produtoId,
  required ModoMovimento modo,
}) async {
  final mensagem = await showDialog<String>(
    context: context,
    builder: (_) => _MovimentoDialog(produtoId: produtoId, modo: modo),
  );
  if (mensagem == null) return;
  ref.invalidate(posicaoEstoqueProvider);
  ref.invalidate(resumoEstoqueProvider);
  ref.invalidate(movimentacoesProvider);
  ref.invalidate(produtosPaginaProvider);
  if (context.mounted) mostrarSucesso(context, mensagem);
}

final _produtoMovimentoProvider = FutureProvider.autoDispose.family<Produto, String>(
  (ref, id) => ref.watch(produtosRepositoryProvider).buscar(id),
);

class _MovimentoDialog extends ConsumerWidget {
  const _MovimentoDialog({required this.produtoId, required this.modo});

  final String produtoId;
  final ModoMovimento modo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final produto = ref.watch(_produtoMovimentoProvider(produtoId));
    final unidades = ref.watch(unidadesProvider);
    final erro = produto.error ?? unidades.error;
    if (erro != null) {
      return AlertDialog(
        content: ErroView(mensagem: mensagemDeErro(erro)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))],
      );
    }
    if (!produto.hasValue || !unidades.hasValue) {
      return const AlertDialog(content: SizedBox(height: 120, child: Carregando()));
    }
    return _Formulario(produto: produto.value!, unidades: unidades.value!, modo: modo);
  }
}

/// Opção de unidade em que a quantidade pode ser informada.
class _OpcaoUnidade {
  const _OpcaoUnidade(this.chave, this.rotulo, {this.unidadeId, this.embalagemId});

  final String chave;
  final String rotulo;
  final String? unidadeId;
  final String? embalagemId;
}

class _Formulario extends ConsumerStatefulWidget {
  const _Formulario({required this.produto, required this.unidades, required this.modo});

  final Produto produto;
  final List<UnidadeMedida> unidades;
  final ModoMovimento modo;

  @override
  ConsumerState<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends ConsumerState<_Formulario> {
  final _form = GlobalKey<FormState>();
  final _quantidade = TextEditingController();
  final _observacao = TextEditingController();
  late final List<_OpcaoUnidade> _opcoes = _montarOpcoes();
  late String _unidadeChave = _opcoes.first.chave;
  TipoMovimentacao _tipoSaida = TipoMovimentacao.consumoInterno;
  bool _salvando = false;
  String? _erro;

  Produto get _p => widget.produto;
  String get _sigla => _p.unidadeEstoque.sigla;

  @override
  void dispose() {
    _quantidade.dispose();
    _observacao.dispose();
    super.dispose();
  }

  List<_OpcaoUnidade> _montarOpcoes() {
    final estoque = _p.unidadeEstoque;
    return [
      _OpcaoUnidade('u:${estoque.id}', estoque.descricao),
      for (final u in widget.unidades)
        if (!u.embalagem && u.grandeza == estoque.grandeza && u.id != estoque.id)
          _OpcaoUnidade('u:${u.id}', u.descricao, unidadeId: u.id),
      for (final e in _p.embalagens)
        _OpcaoUnidade('e:${e.id}', '${e.descricao} (${formatarQuantidade(e.fator)} $_sigla)', embalagemId: e.id),
    ];
  }

  String get _titulo => switch (widget.modo) {
        ModoMovimento.entrada => 'Registrar entrada',
        ModoMovimento.saida => 'Registrar saída',
        ModoMovimento.ajuste => 'Ajustar estoque',
      };

  bool get _observacaoObrigatoria =>
      widget.modo == ModoMovimento.ajuste ||
      (widget.modo == ModoMovimento.saida && _tipoSaida == TipoMovimentacao.perda);

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    final repo = ref.read(estoqueRepositoryProvider);
    final quantidade = lerDecimal(_quantidade.text)!;
    final opcao = _opcoes.firstWhere((o) => o.chave == _unidadeChave);
    final observacao = _observacao.text.trim().isEmpty ? null : _observacao.text.trim();
    try {
      final String mensagem;
      switch (widget.modo) {
        case ModoMovimento.entrada:
          final m = await repo.entrada(
            produtoId: _p.id,
            quantidade: quantidade,
            unidadeId: opcao.unidadeId,
            embalagemId: opcao.embalagemId,
            observacao: observacao,
          );
          mensagem = 'Entrada de ${formatarQuantidade(m.quantidade)} $_sigla registrada. '
              'Saldo: ${formatarQuantidade(m.saldoPosterior)} $_sigla.';
        case ModoMovimento.saida:
          final m = await repo.saida(
            produtoId: _p.id,
            tipo: _tipoSaida,
            quantidade: quantidade,
            unidadeId: opcao.unidadeId,
            embalagemId: opcao.embalagemId,
            observacao: observacao,
          );
          mensagem = '${_tipoSaida.rotulo}: ${formatarQuantidade(m.quantidade.abs())} $_sigla. '
              'Saldo: ${formatarQuantidade(m.saldoPosterior)} $_sigla.';
        case ModoMovimento.ajuste:
          final m = await repo.ajuste(produtoId: _p.id, quantidadeContada: quantidade, observacao: observacao!);
          mensagem = m == null
              ? 'Sem diferença: o saldo já era ${formatarQuantidade(quantidade)} $_sigla.'
              : 'Ajuste de ${m.quantidade > 0 ? '+' : ''}${formatarQuantidade(m.quantidade)} $_sigla registrado.';
      }
      if (mounted) Navigator.pop(context, mensagem);
    } catch (e) {
      setState(() => _erro = mensagemDeErro(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ajuste = widget.modo == ModoMovimento.ajuste;
    return AlertDialog(
      title: Text(_titulo),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_p.nome, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Text('Saldo atual: ${formatarQuantidade(_p.estoqueAtual)} $_sigla',
                    style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 20),
                if (widget.modo == ModoMovimento.saida) ...[
                  DropdownButtonFormField<TipoMovimentacao>(
                    initialValue: _tipoSaida,
                    decoration: const InputDecoration(labelText: 'Tipo de saída'),
                    items: [
                      for (final t in TipoMovimentacao.saidasManuais) DropdownMenuItem(value: t, child: Text(t.rotulo)),
                    ],
                    onChanged: (t) => setState(() => _tipoSaida = t!),
                  ),
                  const SizedBox(height: 14),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantidade,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: ajuste ? 'Quantidade contada' : 'Quantidade',
                          suffixText: ajuste ? _sigla : null,
                        ),
                        validator: (v) {
                          final n = lerDecimal(v);
                          if (n == null) return 'Informe a quantidade';
                          if (ajuste ? n < 0 : n <= 0) return ajuste ? 'Não pode ser negativa' : 'Deve ser maior que zero';
                          return null;
                        },
                      ),
                    ),
                    if (!ajuste) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _unidadeChave,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Unidade'),
                          items: [
                            for (final o in _opcoes)
                              DropdownMenuItem(value: o.chave, child: Text(o.rotulo, overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) => setState(() => _unidadeChave = v!),
                        ),
                      ),
                    ],
                  ],
                ),
                if (ajuste)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Informe a quantidade física encontrada. O sistema registra a diferença como ajuste.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _observacao,
                  maxLength: 500,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: _observacaoObrigatoria ? 'Motivo *' : 'Observação',
                    hintText: switch (widget.modo) {
                      ModoMovimento.entrada => 'Ex.: estoque inicial, transferência',
                      ModoMovimento.saida => 'Ex.: garrafa quebrada, consumo da equipe',
                      ModoMovimento.ajuste => 'Ex.: conferência do fim do turno',
                    },
                  ),
                  validator: (v) =>
                      _observacaoObrigatoria && (v == null || v.trim().isEmpty) ? 'Informe o motivo' : null,
                ),
                if (_erro != null) Text(_erro!, style: const TextStyle(color: AppCores.perigo)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _salvando ? null : _salvar,
          child: _salvando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Registrar'),
        ),
      ],
    );
  }
}
