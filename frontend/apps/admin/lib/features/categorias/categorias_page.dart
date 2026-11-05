import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'categorias.dart';

class CategoriasPage extends ConsumerWidget {
  const CategoriasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categorias = ref.watch(categoriasProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CabecalhoPagina(
          titulo: 'Categorias',
          subtitulo: 'Organizam produtos no PDV, no cardápio e nos relatórios',
          acoes: [
            FilledButton.icon(
              onPressed: () => _abrirFormulario(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Nova categoria'),
            ),
          ],
        ),
        Card(
          child: categorias.when(
            loading: () => const Carregando(),
            error: (e, _) => ErroView(
              mensagem: mensagemDeErro(e),
              aoTentarNovamente: () => ref.invalidate(categoriasProvider),
            ),
            data: (lista) => lista.isEmpty
                ? const EstadoVazio(icone: Icons.category_outlined, titulo: 'Nenhuma categoria cadastrada')
                : Column(
                    children: [
                      for (final (i, c) in lista.indexed) ...[
                        if (i > 0) const Divider(),
                        _CategoriaTile(categoria: c),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _CategoriaTile extends ConsumerWidget {
  const _CategoriaTile({required this.categoria});

  final Categoria categoria;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = categoria;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: AppCores.fundo,
        child: Text('${c.ordem}', style: const TextStyle(fontSize: 12, color: AppCores.grafite)),
      ),
      title: Text(c.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(spacing: 6, runSpacing: 4, children: [
          Etiqueta.status(c.ativo),
          if (c.exibirCardapio)
            const Etiqueta('No cardápio', cor: AppCores.ambarEscuro, icone: Icons.qr_code_2)
          else
            Etiqueta('Fora do cardápio', cor: Colors.grey.shade600),
        ]),
      ),
      onTap: () => _abrirFormulario(context, ref, categoria: c),
      trailing: PopupMenuButton<String>(
        tooltip: 'Ações',
        onSelected: (acao) => _executar(context, ref, acao),
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'editar', child: Text('Editar')),
          PopupMenuItem(value: 'status', child: Text(c.ativo ? 'Inativar' : 'Ativar')),
          const PopupMenuItem(value: 'excluir', child: Text('Excluir')),
        ],
      ),
    );
  }

  Future<void> _executar(BuildContext context, WidgetRef ref, String acao) async {
    final repo = ref.read(categoriasRepositoryProvider);
    try {
      switch (acao) {
        case 'editar':
          await _abrirFormulario(context, ref, categoria: categoria);
          return;
        case 'status':
          await repo.alterarStatus(categoria.id, !categoria.ativo);
          if (context.mounted) {
            mostrarSucesso(context, 'Categoria ${categoria.ativo ? 'inativada' : 'ativada'}.');
          }
        case 'excluir':
          final ok = await confirmar(
            context,
            titulo: 'Excluir categoria',
            mensagem: 'Excluir "${categoria.nome}"? Só é possível se nenhum produto usar esta categoria.',
            acao: 'Excluir',
            perigoso: true,
          );
          if (!ok) return;
          await repo.excluir(categoria.id);
          if (context.mounted) mostrarSucesso(context, 'Categoria excluída.');
      }
      ref.invalidate(categoriasProvider);
    } catch (e) {
      if (context.mounted) mostrarErro(context, e);
    }
  }
}

Future<void> _abrirFormulario(BuildContext context, WidgetRef ref, {Categoria? categoria}) async {
  final salvou = await showDialog<bool>(
    context: context,
    builder: (_) => _CategoriaFormDialog(categoria: categoria),
  );
  if (salvou == true) {
    ref.invalidate(categoriasProvider);
    if (context.mounted) mostrarSucesso(context, 'Categoria salva.');
  }
}

class _CategoriaFormDialog extends ConsumerStatefulWidget {
  const _CategoriaFormDialog({this.categoria});

  final Categoria? categoria;

  @override
  ConsumerState<_CategoriaFormDialog> createState() => _CategoriaFormDialogState();
}

class _CategoriaFormDialogState extends ConsumerState<_CategoriaFormDialog> {
  final _form = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.categoria?.nome);
  late final _ordem = TextEditingController(text: '${widget.categoria?.ordem ?? 0}');
  late bool _exibirCardapio = widget.categoria?.exibirCardapio ?? true;
  bool _salvando = false;
  ApiException? _erro;

  @override
  void dispose() {
    _nome.dispose();
    _ordem.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await ref.read(categoriasRepositoryProvider).salvar(
            id: widget.categoria?.id,
            nome: _nome.text.trim(),
            ordem: int.tryParse(_ordem.text) ?? 0,
            exibirCardapio: _exibirCardapio,
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.categoria == null ? 'Nova categoria' : 'Editar categoria'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nome,
                autofocus: true,
                decoration: InputDecoration(labelText: 'Nome', errorText: _erro?.campos['nome']),
                maxLength: 60,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              TextFormField(
                controller: _ordem,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Ordem de exibição',
                  helperText: 'Menor número aparece primeiro',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Exibir no cardápio digital'),
                value: _exibirCardapio,
                onChanged: (v) => setState(() => _exibirCardapio = v),
              ),
              if (_erro != null && _erro!.campos.isEmpty)
                Text(_erro!.mensagem, style: const TextStyle(color: AppCores.perigo)),
            ],
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
