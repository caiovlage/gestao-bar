import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';

import 'receitas.dart';

/// Consulta da receita na cozinha: letra grande e ajustável, ingredientes e modo de preparo formatados.
class ReceitaPage extends ConsumerStatefulWidget {
  const ReceitaPage({super.key, required this.receitaId});

  final String receitaId;

  @override
  ConsumerState<ReceitaPage> createState() => _ReceitaPageState();
}

class _ReceitaPageState extends ConsumerState<ReceitaPage> {
  double _escala = 1.15;

  Future<void> _excluir(Receita r) async {
    final ok = await confirmar(context,
        titulo: 'Excluir receita', mensagem: 'Excluir "${r.nome}"?', acao: 'Excluir', perigoso: true);
    if (!ok) return;
    try {
      await ref.read(receitasRepositoryProvider).excluir(r.id);
      ref.invalidate(receitasProvider);
      if (mounted) {
        mostrarSucesso(context, 'Receita excluída.');
        context.go('/receitas');
      }
    } catch (e) {
      if (mounted) mostrarErro(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final receita = ref.watch(receitaProvider(widget.receitaId));
    return receita.when(
      loading: () => const Carregando(),
      error: (e, _) => ErroView(
        mensagem: mensagemDeErro(e),
        aoTentarNovamente: () => ref.invalidate(receitaProvider(widget.receitaId)),
      ),
      data: _conteudo,
    );
  }

  Widget _conteudo(Receita r) {
    final base = 16 * _escala;
    final url = ref.read(receitasRepositoryProvider).urlImagem(r.fotoUrl);

    Widget bloco(String titulo, String? html, String vazio) => Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(titulo, style: TextStyle(fontSize: base * 1.25, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              if (html == null)
                Text(vazio, style: TextStyle(color: Colors.grey.shade600, fontSize: base))
              else
                HtmlWidget(html, textStyle: TextStyle(fontSize: base * 1.05, height: 1.55)),
            ]),
          ),
        );

    final cabecalho = CabecalhoPagina(
      titulo: r.nome,
      subtitulo: [
        if (r.tempoPreparoMin != null) '${r.tempoPreparoMin} min',
        if (r.rendimento != null) r.rendimento!,
      ].join(' · '),
      acoes: [
        OutlinedButton.icon(
          onPressed: () => context.go('/receitas'),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Receitas'),
        ),
        IconButton.outlined(
          tooltip: 'Diminuir letra',
          onPressed: _escala > 0.9 ? () => setState(() => _escala -= 0.15) : null,
          icon: const Icon(Icons.text_decrease),
        ),
        IconButton.outlined(
          tooltip: 'Aumentar letra',
          onPressed: _escala < 2 ? () => setState(() => _escala += 0.15) : null,
          icon: const Icon(Icons.text_increase),
        ),
        OutlinedButton.icon(
          onPressed: () => context.go('/receitas/${r.id}/editar'),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar'),
        ),
        IconButton.outlined(
          tooltip: 'Excluir',
          onPressed: () => _excluir(r),
          icon: const Icon(Icons.delete_outline, color: AppCores.perigo),
        ),
      ],
    );

    final foto = url == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
              ),
            ),
          );
    final ingredientes = bloco('Ingredientes', r.ingredientes, 'Sem ingredientes cadastrados.');
    final preparo = bloco('Modo de preparo', r.modoPreparo, 'Sem modo de preparo cadastrado.');

    return LayoutBuilder(builder: (context, c) {
      final largo = c.maxWidth >= 1000;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        cabecalho,
        if (largo)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 400, child: Column(children: [?foto, ingredientes])),
            const SizedBox(width: 20),
            Expanded(child: preparo),
          ])
        else ...[
          ?foto,
          ingredientes,
          const SizedBox(height: 12),
          preparo,
        ],
      ]);
    });
  }
}
