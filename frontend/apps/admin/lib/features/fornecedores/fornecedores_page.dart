import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/widgets/paginacao.dart';
import 'fornecedores.dart';

class FornecedoresPage extends ConsumerStatefulWidget {
  const FornecedoresPage({super.key});

  @override
  ConsumerState<FornecedoresPage> createState() => _FornecedoresPageState();
}

class _FornecedoresPageState extends ConsumerState<FornecedoresPage> {
  late final _busca = TextEditingController(text: ref.read(filtroFornecedoresProvider).nome);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _busca.dispose();
    super.dispose();
  }

  void _aoDigitar(String texto) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400),
        () => ref.read(filtroFornecedoresProvider.notifier).pesquisar(texto.trim()));
  }

  Future<void> _abrirFormulario({Fornecedor? fornecedor}) async {
    final salvou = await showDialog<bool>(
      context: context,
      builder: (_) => _FornecedorFormDialog(fornecedor: fornecedor),
    );
    if (salvou == true) {
      ref.invalidate(fornecedoresPaginaProvider);
      if (mounted) mostrarSucesso(context, 'Fornecedor salvo.');
    }
  }

  Future<void> _alternarStatus(Fornecedor f) async {
    try {
      await ref.read(fornecedoresRepositoryProvider).alterarStatus(f.id, !f.ativo);
      ref.invalidate(fornecedoresPaginaProvider);
      if (mounted) mostrarSucesso(context, 'Fornecedor ${f.ativo ? 'inativado' : 'ativado'}.');
    } catch (e) {
      if (mounted) mostrarErro(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pagina = ref.watch(fornecedoresPaginaProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CabecalhoPagina(
          titulo: 'Fornecedores',
          acoes: [
            FilledButton.icon(
              onPressed: () => _abrirFormulario(),
              icon: const Icon(Icons.add),
              label: const Text('Novo fornecedor'),
            ),
          ],
        ),
        TextField(
          controller: _busca,
          onChanged: _aoDigitar,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Pesquisar por nome'),
        ),
        const SizedBox(height: 16),
        Card(
          child: pagina.when(
            loading: () => const Carregando(),
            error: (e, _) => ErroView(
              mensagem: mensagemDeErro(e),
              aoTentarNovamente: () => ref.invalidate(fornecedoresPaginaProvider),
            ),
            data: (p) => p.conteudo.isEmpty
                ? const EstadoVazio(icone: Icons.local_shipping_outlined, titulo: 'Nenhum fornecedor encontrado')
                : Column(children: [
                    for (final (i, f) in p.conteudo.indexed) ...[
                      if (i > 0) const Divider(),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        title: Text(f.nomeExibicao, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          [f.telefone, f.email, if (f.cnpj != null) 'CNPJ ${f.cnpj}']
                              .whereType<String>()
                              .join('  •  '),
                        ),
                        leading: const CircleAvatar(child: Icon(Icons.local_shipping_outlined)),
                        trailing: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 4,
                          children: [
                            Etiqueta.status(f.ativo),
                            PopupMenuButton<String>(
                              tooltip: 'Ações',
                              onSelected: (a) => a == 'editar' ? _abrirFormulario(fornecedor: f) : _alternarStatus(f),
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'editar', child: Text('Editar')),
                                PopupMenuItem(value: 'status', child: Text(f.ativo ? 'Inativar' : 'Ativar')),
                              ],
                            ),
                          ],
                        ),
                        onTap: () => _abrirFormulario(fornecedor: f),
                      ),
                    ],
                    const Divider(),
                    Paginacao(
                      pagina: p,
                      aoMudar: (n) => ref.read(filtroFornecedoresProvider.notifier).irParaPagina(n),
                    ),
                  ]),
          ),
        ),
      ],
    );
  }
}

class _FornecedorFormDialog extends ConsumerStatefulWidget {
  const _FornecedorFormDialog({this.fornecedor});

  final Fornecedor? fornecedor;

  @override
  ConsumerState<_FornecedorFormDialog> createState() => _FornecedorFormDialogState();
}

class _FornecedorFormDialogState extends ConsumerState<_FornecedorFormDialog> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _campos = {
    'nome': TextEditingController(text: widget.fornecedor?.nome),
    'nomeFantasia': TextEditingController(text: widget.fornecedor?.nomeFantasia),
    'cnpj': TextEditingController(text: widget.fornecedor?.cnpj),
    'telefone': TextEditingController(text: widget.fornecedor?.telefone),
    'email': TextEditingController(text: widget.fornecedor?.email),
    'endereco': TextEditingController(text: widget.fornecedor?.endereco),
    'observacoes': TextEditingController(text: widget.fornecedor?.observacoes),
  };
  bool _salvando = false;
  ApiException? _erro;

  @override
  void dispose() {
    for (final c in _campos.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      final corpo = {for (final e in _campos.entries) e.key: e.value.text.trim()};
      await ref.read(fornecedoresRepositoryProvider).salvar(widget.fornecedor?.id, corpo);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Widget _campo(String chave, String rotulo, {bool obrigatorio = false, int linhas = 1, TextInputType? teclado}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _campos[chave],
        maxLines: linhas,
        keyboardType: teclado,
        decoration: InputDecoration(labelText: rotulo, errorText: _erro?.campos[chave]),
        validator: obrigatorio ? (v) => (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.fornecedor == null ? 'Novo fornecedor' : 'Editar fornecedor'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _campo('nome', 'Razão social / nome', obrigatorio: true),
                _campo('nomeFantasia', 'Nome fantasia'),
                _campo('cnpj', 'CNPJ (opcional)', teclado: TextInputType.number),
                _campo('telefone', 'Telefone', teclado: TextInputType.phone),
                _campo('email', 'E-mail', teclado: TextInputType.emailAddress),
                _campo('endereco', 'Endereço'),
                _campo('observacoes', 'Observações', linhas: 3),
                if (_erro != null && _erro!.campos.isEmpty)
                  Text(_erro!.mensagem, style: const TextStyle(color: AppCores.perigo)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: _salvando ? null : _salvar, child: const Text('Salvar')),
      ],
    );
  }
}
