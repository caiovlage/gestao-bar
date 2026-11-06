import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'receitas.dart';

/// Lista de receitas para consulta rápida.
class ReceitasPage extends ConsumerStatefulWidget {
  const ReceitasPage({super.key});

  @override
  ConsumerState<ReceitasPage> createState() => _ReceitasPageState();
}

class _ReceitasPageState extends ConsumerState<ReceitasPage> {
  late final _busca = TextEditingController(text: ref.read(buscaReceitasProvider));
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final receitas = ref.watch(receitasProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CabecalhoPagina(
          titulo: 'Receitas',
          subtitulo: 'Consulta rápida para a cozinha',
          acoes: [
            FilledButton.icon(
              onPressed: () => context.go('/receitas/nova'),
              icon: const Icon(Icons.add),
              label: const Text('Nova receita'),
            ),
          ],
        ),
        SizedBox(
          width: 360,
          child: TextField(
            controller: _busca,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar receita'),
            onChanged: (t) {
              _debounce?.cancel();
              _debounce = Timer(
                const Duration(milliseconds: 300),
                () => ref.read(buscaReceitasProvider.notifier).mudar(t.trim()),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        receitas.when(
          loading: () => const Card(child: Carregando()),
          error: (e, _) => Card(
            child: ErroView(mensagem: mensagemDeErro(e), aoTentarNovamente: () => ref.invalidate(receitasProvider)),
          ),
          data: (p) => p.conteudo.isEmpty
              ? Card(
                  child: EstadoVazio(
                    icone: Icons.menu_book_outlined,
                    titulo: 'Nenhuma receita encontrada',
                    descricao: 'Cadastre as receitas da casa. Dá para colar o texto direto de um site.',
                    acao: OutlinedButton.icon(
                      onPressed: () => context.go('/receitas/nova'),
                      icon: const Icon(Icons.add),
                      label: const Text('Cadastrar receita'),
                    ),
                  ),
                )
              : Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [for (final r in p.conteudo) _CartaoReceita(receita: r)],
                ),
        ),
      ],
    );
  }
}

class _CartaoReceita extends ConsumerWidget {
  const _CartaoReceita({required this.receita});

  final ReceitaResumo receita;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = receita;
    final url = ref.read(receitasRepositoryProvider).urlImagem(r.fotoUrl);
    final semFoto = Container(
      color: AppCores.fundo,
      child: Icon(Icons.restaurant, size: 44, color: Colors.grey.shade400),
    );
    return SizedBox(
      width: 260,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go('/receitas/${r.id}'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: url == null ? semFoto : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => semFoto),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.nome,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                if (r.tempoPreparoMin != null || r.rendimento != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (r.tempoPreparoMin != null) '${r.tempoPreparoMin} min',
                      if (r.rendimento != null) r.rendimento!,
                    ].join(' · '),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
