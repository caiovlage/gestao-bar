import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/widgets/editor_rico/editor_rico.dart';
import '../produtos/produto_imagem.dart';
import 'receitas.dart';

/// Cadastro/edição de receita.
class ReceitaFormPage extends ConsumerWidget {
  const ReceitaFormPage({super.key, this.receitaId});

  final String? receitaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (receitaId == null) return const _Formulario(receita: null);
    return ref.watch(receitaProvider(receitaId!)).when(
          loading: () => const Carregando(),
          error: (e, _) => ErroView(
            mensagem: mensagemDeErro(e),
            aoTentarNovamente: () => ref.invalidate(receitaProvider(receitaId!)),
          ),
          data: (r) => _Formulario(key: ValueKey(r.id), receita: r),
        );
  }
}

class _Formulario extends ConsumerStatefulWidget {
  const _Formulario({super.key, required this.receita});

  final Receita? receita;

  @override
  ConsumerState<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends ConsumerState<_Formulario> {
  final _form = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.receita?.nome);
  late final _rendimento = TextEditingController(text: widget.receita?.rendimento);
  late final _tempo = TextEditingController(text: widget.receita?.tempoPreparoMin?.toString() ?? '');
  late String? _ingredientes = widget.receita?.ingredientes;
  late String? _modoPreparo = widget.receita?.modoPreparo;
  Uint8List? _novaFoto;
  String? _nomeNovaFoto;
  bool _salvando = false;
  ApiException? _erro;

  @override
  void dispose() {
    _nome.dispose();
    _rendimento.dispose();
    _tempo.dispose();
    super.dispose();
  }

  Future<void> _escolherFoto() async {
    final arquivo = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (arquivo == null) return;
    final bytes = await arquivo.readAsBytes();
    setState(() {
      _novaFoto = bytes;
      _nomeNovaFoto = arquivo.name;
    });
  }

  Future<void> _removerFoto() async {
    if (_novaFoto != null) {
      setState(() => _novaFoto = null);
      return;
    }
    final id = widget.receita!.id;
    try {
      await ref.read(receitasRepositoryProvider).removerFoto(id);
      ref.invalidate(receitaProvider(id));
      ref.invalidate(receitasProvider);
    } catch (e) {
      if (mounted) mostrarErro(context, e);
    }
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    final repo = ref.read(receitasRepositoryProvider);
    try {
      final salva = await repo.salvar(
        widget.receita?.id,
        nome: _nome.text.trim(),
        rendimento: _rendimento.text.trim().isEmpty ? null : _rendimento.text.trim(),
        tempoPreparoMin: int.tryParse(_tempo.text.trim()),
        ingredientes: _ingredientes,
        modoPreparo: _modoPreparo,
      );
      if (_novaFoto != null) {
        try {
          await repo.enviarFoto(salva.id, _novaFoto!, _nomeNovaFoto ?? 'foto.jpg');
        } catch (e) {
          if (mounted) mostrarErro(context, 'Receita salva, mas a foto não foi enviada: ${mensagemDeErro(e)}');
        }
      }
      ref.invalidate(receitasProvider);
      ref.invalidate(receitaProvider(salva.id));
      if (mounted) {
        mostrarSucesso(context, widget.receita == null ? 'Receita cadastrada.' : 'Receita atualizada.');
        context.go('/receitas/${salva.id}');
      }
    } on ApiException catch (e) {
      setState(() => _erro = e);
      if (mounted && e.campos.isEmpty) mostrarErro(context, e);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.receita;
    Widget titulo(String texto) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(texto, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        );

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CabecalhoPagina(
            titulo: r == null ? 'Nova receita' : 'Editar: ${r.nome}',
            acoes: [
              OutlinedButton.icon(
                onPressed: () => context.go(r == null ? '/receitas' : '/receitas/${r.id}'),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Voltar'),
              ),
              FilledButton.icon(
                onPressed: _salvando ? null : _salvar,
                icon: _salvando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: const Text('Salvar'),
              ),
            ],
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextFormField(
                  controller: _nome,
                  maxLength: 120,
                  decoration: InputDecoration(labelText: 'Nome *', errorText: _erro?.campos['nome']),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                ),
                Wrap(spacing: 16, runSpacing: 12, children: [
                  LarguraCampo(
                    largura: 260,
                    child: TextFormField(
                      controller: _rendimento,
                      maxLength: 60,
                      decoration: const InputDecoration(labelText: 'Rendimento', hintText: '4 porções'),
                    ),
                  ),
                  LarguraCampo(
                    largura: 200,
                    child: TextFormField(
                      controller: _tempo,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Tempo de preparo', suffixText: 'min'),
                      validator: (v) =>
                          v != null && v.trim().isNotEmpty && int.tryParse(v.trim()) == null ? 'Número inteiro' : null,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  ProdutoImagem(bytes: _novaFoto, url: ref.read(receitasRepositoryProvider).urlImagem(r?.fotoUrl), tamanho: 72),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(onPressed: _escolherFoto, icon: const Icon(Icons.upload), label: const Text('Foto')),
                  if (_novaFoto != null || r?.fotoUrl != null)
                    TextButton(onPressed: _removerFoto, child: const Text('Remover')),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                titulo('Ingredientes'),
                EditorRico(
                  htmlInicial: _ingredientes,
                  altura: 240,
                  aoAlterar: (h) => _ingredientes = h,
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                titulo('Modo de preparo'),
                EditorRico(htmlInicial: _modoPreparo, aoAlterar: (h) => _modoPreparo = h),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
