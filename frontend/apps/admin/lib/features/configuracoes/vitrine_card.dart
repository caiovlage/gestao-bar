import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

/// Tipos de seção de destaque do cardápio e como cada uma é montada.
enum TipoSecao {
  sugestoes('SUGESTOES', Icons.star_outline, 'Produtos marcados "Sugestão da casa" no cadastro'),
  promocoes('PROMOCOES', Icons.local_offer_outlined, 'Produtos com preço promocional valendo hoje (maior desconto primeiro)'),
  maisPedidos('MAIS_PEDIDOS', Icons.local_fire_department_outlined, 'Mais vendidos nos últimos 30 dias'),
  menosPedidos('MENOS_PEDIDOS', Icons.trending_down, 'Menos vendidos nos últimos 30 dias — ajuda a girar o estoque'),
  novidades('NOVIDADES', Icons.fiber_new_outlined, 'Produtos cadastrados mais recentemente');

  const TipoSecao(this.api, this.icone, this.regra);
  final String api;
  final IconData icone;
  final String regra;

  static TipoSecao fromApi(String v) => values.firstWhere((t) => t.api == v);
}

class _SecaoEdicao {
  _SecaoEdicao(this.tipo, String titulo, this.ativa, this.quantidade) : titulo = TextEditingController(text: titulo);

  final TipoSecao tipo;
  final TextEditingController titulo;
  bool ativa;
  int quantidade;
}

final _vitrineProvider = FutureProvider.autoDispose<List<_SecaoEdicao>>((ref) async {
  final dados = await ref.watch(apiClientProvider).get('/api/admin/cardapio/vitrine') as List;
  return [
    for (final s in dados.cast<Map<String, dynamic>>())
      _SecaoEdicao(TipoSecao.fromApi(s['tipo'] as String), s['titulo'] as String, s['ativa'] as bool,
          s['quantidade'] as int),
  ];
});

/// Configuração da vitrine: quais seções de destaque aparecem no topo do cardápio, em que ordem,
/// com que título e quantos produtos cada uma mostra.
class VitrineCard extends ConsumerWidget {
  const VitrineCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vitrine = ref.watch(_vitrineProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Vitrine do cardápio',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Seções de destaque no topo do cardápio. Ligue as que quiser, arraste para mudar a ordem e '
            'dê o título que preferir (ex.: "Happy hour", "Experimente também"). O conteúdo é atualizado '
            'automaticamente; seções sem produtos não aparecem.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 12),
          vitrine.when(
            loading: () => const Carregando(),
            error: (e, _) => ErroView(
              mensagem: mensagemDeErro(e),
              aoTentarNovamente: () => ref.invalidate(_vitrineProvider),
            ),
            data: (secoes) => _EditorVitrine(secoes: secoes),
          ),
        ]),
      ),
    );
  }
}

class _EditorVitrine extends ConsumerStatefulWidget {
  const _EditorVitrine({required this.secoes});

  final List<_SecaoEdicao> secoes;

  @override
  ConsumerState<_EditorVitrine> createState() => _EditorVitrineState();
}

class _EditorVitrineState extends ConsumerState<_EditorVitrine> {
  late final List<_SecaoEdicao> _secoes = [...widget.secoes];
  bool _salvando = false;

  @override
  void dispose() {
    for (final s in _secoes) {
      s.titulo.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_secoes.any((s) => s.titulo.text.trim().isEmpty)) {
      mostrarErro(context, 'Dê um título para todas as seções.');
      return;
    }
    setState(() => _salvando = true);
    try {
      await ref.read(apiClientProvider).put('/api/admin/cardapio/vitrine', corpo: {
        'secoes': [
          for (final s in _secoes)
            {'tipo': s.tipo.api, 'titulo': s.titulo.text.trim(), 'ativa': s.ativa, 'quantidade': s.quantidade},
        ],
      });
      if (mounted) mostrarSucesso(context, 'Vitrine salva. O cardápio já mostra a nova organização.');
    } catch (e) {
      if (mounted) mostrarErro(context, e);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        onReorder: (de, para) => setState(() {
          if (para > de) para--;
          _secoes.insert(para, _secoes.removeAt(de));
        }),
        children: [
          for (final (i, s) in _secoes.indexed)
            Container(
              key: ValueKey(s.tipo),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
              decoration: BoxDecoration(
                color: s.ativa ? AppCores.ambar.withValues(alpha: 0.06) : AppCores.fundo,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: s.ativa ? AppCores.ambar.withValues(alpha: 0.4) : Colors.grey.shade300),
              ),
              child: Row(children: [
                ReorderableDragStartListener(
                  index: i,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.drag_indicator, color: Colors.grey),
                  ),
                ),
                Icon(s.tipo.icone, color: s.ativa ? AppCores.ambarEscuro : Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    SizedBox(
                      width: 240,
                      child: TextField(
                        controller: s.titulo,
                        maxLength: 60,
                        decoration: const InputDecoration(labelText: 'Título', counterText: '', isDense: true),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: DropdownButtonFormField<int>(
                        initialValue: s.quantidade,
                        isDense: true,
                        decoration: const InputDecoration(labelText: 'Produtos', isDense: true),
                        items: [for (var n = 1; n <= 12; n++) DropdownMenuItem(value: n, child: Text('até $n'))],
                        onChanged: (n) => setState(() => s.quantidade = n ?? s.quantidade),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Text(s.tipo.regra, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ),
                  ]),
                ),
                Switch(value: s.ativa, onChanged: (v) => setState(() => s.ativa = v)),
              ]),
            ),
        ],
      ),
      const SizedBox(height: 4),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton(onPressed: _salvando ? null : _salvar, child: const Text('Salvar vitrine')),
      ),
    ]);
  }
}
