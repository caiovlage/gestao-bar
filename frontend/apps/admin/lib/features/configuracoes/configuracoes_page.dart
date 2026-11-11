import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../relatorios/relatorios.dart';
import '../unidades/unidades.dart';
import 'backup_card.dart';
import '../notificacoes/notificacoes.dart';
import 'cardapio_digital_card.dart';
import 'vitrine_card.dart';

final _configuracoesProvider = FutureProvider.autoDispose<Map<String, String>>((ref) async {
  final dados = await ref.watch(apiClientProvider).get('/api/admin/configuracoes') as List;
  return {for (final c in dados.cast<Map<String, dynamic>>()) c['chave'] as String: c['valor'] as String};
});

class ConfiguracoesPage extends ConsumerWidget {
  const ConfiguracoesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configs = ref.watch(_configuracoesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CabecalhoPagina(titulo: 'Configurações'),
        Card(
          child: configs.when(
            loading: () => const Carregando(),
            error: (e, _) => ErroView(
              mensagem: mensagemDeErro(e),
              aoTentarNovamente: () => ref.invalidate(_configuracoesProvider),
            ),
            data: (valores) => _ConfiguracoesGerais(valores: valores),
          ),
        ),
        const SizedBox(height: 16),
        const NotificacoesCard(),
        const SizedBox(height: 16),
        const CardapioDigitalCard(),
        const SizedBox(height: 16),
        const VitrineCard(),
        const SizedBox(height: 16),
        const BackupCard(),
        const SizedBox(height: 16),
        const _UnidadesCard(),
      ],
    );
  }
}

class _ConfiguracoesGerais extends ConsumerStatefulWidget {
  const _ConfiguracoesGerais({required this.valores});

  final Map<String, String> valores;

  @override
  ConsumerState<_ConfiguracoesGerais> createState() => _ConfiguracoesGeraisState();
}

class _ConfiguracoesGeraisState extends ConsumerState<_ConfiguracoesGerais> {
  late final _nomeBar = TextEditingController(text: widget.valores['nome_bar']);
  late bool _cardapioAberto = widget.valores['cardapio_aberto'] == 'true';
  late bool _estoqueNegativo = widget.valores['permitir_estoque_negativo'] == 'true';
  bool _salvando = false;

  @override
  void dispose() {
    _nomeBar.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_estoqueNegativo && widget.valores['permitir_estoque_negativo'] != 'true') {
      final ok = await confirmar(context,
          titulo: 'Permitir estoque negativo?',
          mensagem: 'Vendas poderão ser registradas mesmo sem saldo, o que pode esconder erros de estoque.',
          acao: 'Permitir');
      if (!ok) return;
    }
    setState(() => _salvando = true);
    try {
      await ref.read(apiClientProvider).put('/api/admin/configuracoes', corpo: {
        'nome_bar': _nomeBar.text.trim(),
        'cardapio_aberto': '$_cardapioAberto',
        'permitir_estoque_negativo': '$_estoqueNegativo',
      });
      ref.invalidate(_configuracoesProvider);
      ref.invalidate(painelDashboardProvider);
      ref.invalidate(painelRelatorioProvider);
      if (mounted) mostrarSucesso(context, 'Configurações salvas.');
    } catch (e) {
      if (mounted) mostrarErro(context, e);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Geral', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _nomeBar,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Nome do bar', helperText: 'Usado no painel e nos comprovantes (o cardápio exibe o logo)'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Cardápio aberto para pedidos'),
            subtitle: const Text('Desative para pausar os pedidos pelo cardápio (ex.: sem entregadores)'),
            value: _cardapioAberto,
            onChanged: (v) => setState(() => _cardapioAberto = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Permitir estoque negativo'),
            subtitle: const Text('Recomendado manter desativado'),
            value: _estoqueNegativo,
            onChanged: (v) => setState(() => _estoqueNegativo = v),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(onPressed: _salvando ? null : _salvar, child: const Text('Salvar')),
          ),
        ],
      ),
    );
  }
}

class _UnidadesCard extends ConsumerWidget {
  const _UnidadesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unidades = ref.watch(unidadesProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: Text('Unidades de medida',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
              TextButton.icon(
                onPressed: () async {
                  final criou = await showDialog<bool>(context: context, builder: (_) => const _UnidadeDialog());
                  if (criou == true) ref.invalidate(unidadesProvider);
                },
                icon: const Icon(Icons.add),
                label: const Text('Nova unidade'),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              'Conversões automáticas: 1 kg = 1.000 g · 1 L = 1.000 ml. '
              'Caixas e pacotes são definidos em cada produto (ex.: Caixa 12 = 12 un).',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 12),
            unidades.when(
              loading: () => const Carregando(),
              error: (e, _) => ErroView(mensagem: mensagemDeErro(e)),
              data: (lista) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final u in lista)
                    Chip(
                      avatar: CircleAvatar(
                        backgroundColor: AppCores.fundo,
                        child: Text(u.sigla, style: const TextStyle(fontSize: 10)),
                      ),
                      label: Text(
                        u.embalagem || u.unidadeBase
                            ? '${u.nome} · ${u.grandeza.rotulo}'
                            : '${u.nome} · ${formatarQuantidade(u.fatorBase)} '
                                '${u.grandeza == Grandeza.massa ? 'g' : u.grandeza == Grandeza.volume ? 'ml' : 'un'}',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnidadeDialog extends ConsumerStatefulWidget {
  const _UnidadeDialog();

  @override
  ConsumerState<_UnidadeDialog> createState() => _UnidadeDialogState();
}

class _UnidadeDialogState extends ConsumerState<_UnidadeDialog> {
  final _form = GlobalKey<FormState>();
  final _sigla = TextEditingController();
  final _nome = TextEditingController();
  final _fator = TextEditingController();
  Grandeza _grandeza = Grandeza.embalagem;
  String? _erro;

  @override
  void dispose() {
    _sigla.dispose();
    _nome.dispose();
    _fator.dispose();
    super.dispose();
  }

  String get _base => switch (_grandeza) {
        Grandeza.massa => 'g',
        Grandeza.volume => 'ml',
        _ => 'un',
      };

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    try {
      await ref.read(unidadesRepositoryProvider).criar(
            sigla: _sigla.text.trim(),
            nome: _nome.text.trim(),
            grandeza: _grandeza,
            fatorBase: _grandeza == Grandeza.embalagem ? null : lerDecimal(_fator.text),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _erro = mensagemDeErro(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova unidade de medida'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<Grandeza>(
              initialValue: _grandeza,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: [for (final g in Grandeza.values) DropdownMenuItem(value: g, child: Text(g.rotulo))],
              onChanged: (g) => setState(() => _grandeza = g!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sigla,
              maxLength: 10,
              decoration: const InputDecoration(labelText: 'Sigla', hintText: 'fd'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a sigla' : null,
            ),
            TextFormField(
              controller: _nome,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'Nome', hintText: 'Fardo'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
            ),
            if (_grandeza != Grandeza.embalagem)
              TextFormField(
                controller: _fator,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Equivale a', suffixText: _base),
                validator: (v) => (lerDecimal(v) ?? 0) <= 0 ? 'Informe um valor maior que zero' : null,
              ),
            if (_erro != null) Text(_erro!, style: const TextStyle(color: AppCores.perigo)),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: _salvar, child: const Text('Salvar')),
      ],
    );
  }
}
