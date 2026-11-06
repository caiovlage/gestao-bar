import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../fornecedores/fornecedores.dart';
import 'compras.dart';

class ComprasPage extends ConsumerStatefulWidget {
  const ComprasPage({super.key});

  @override
  ConsumerState<ComprasPage> createState() => _ComprasPageState();
}

class _ComprasPageState extends ConsumerState<ComprasPage> {
  bool _sugestoes = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CabecalhoPagina(
          titulo: 'Compras',
          subtitulo: 'Reposição de estoque: sugestões, listas de compras e recebimento',
          acoes: [
            OutlinedButton.icon(
              onPressed: () => context.go('/compras/nova'),
              icon: const Icon(Icons.add),
              label: const Text('Nova lista'),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, icon: Icon(Icons.lightbulb_outline), label: Text('Sugestões')),
              ButtonSegment(value: false, icon: Icon(Icons.list_alt), label: Text('Listas de compras')),
            ],
            selected: {_sugestoes},
            onSelectionChanged: (s) => setState(() => _sugestoes = s.first),
          ),
        ),
        const SizedBox(height: 16),
        if (_sugestoes) const _Sugestoes() else const _Listas(),
      ],
    );
  }
}

class _Sugestoes extends ConsumerStatefulWidget {
  const _Sugestoes();

  @override
  ConsumerState<_Sugestoes> createState() => _SugestoesState();
}

class _SugestoesState extends ConsumerState<_Sugestoes> {
  Set<String>? _selecionados;
  String? _fornecedorId;
  bool _gerando = false;

  Future<void> _gerar() async {
    if (_selecionados == null || _selecionados!.isEmpty) return;
    setState(() => _gerando = true);
    try {
      final compra = await ref.read(comprasRepositoryProvider).criarDaSugestao(_selecionados!.toList(), _fornecedorId);
      ref.invalidate(comprasProvider);
      if (mounted) {
        mostrarSucesso(context, 'Lista de compras nº ${compra.numero} criada.');
        context.go('/compras/${compra.id}');
      }
    } catch (e) {
      if (mounted) mostrarErro(context, e);
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sugestoes = ref.watch(sugestoesCompraProvider);
    final fornecedores = ref.watch(fornecedoresAtivosProvider).value ?? const <Fornecedor>[];
    return sugestoes.when(
      loading: () => const Card(child: Carregando()),
      error: (e, _) => Card(child: ErroView(mensagem: mensagemDeErro(e), aoTentarNovamente: () => ref.invalidate(sugestoesCompraProvider))),
      data: (lista) {
        if (lista.isEmpty) {
          return const Card(
            child: EstadoVazio(
              icone: Icons.check_circle_outline,
              titulo: 'Nenhum produto abaixo do mínimo',
              descricao: 'Defina o estoque mínimo nos produtos para receber sugestões de compra.',
            ),
          );
        }
        final selecionados = _selecionados ??= {for (final s in lista) s.produtoId};
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('${selecionados.length} de ${lista.length} produto(s) selecionado(s)'),
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String?>(
                initialValue: _fornecedorId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Fornecedor da lista (opcional)', isDense: true),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sem fornecedor')),
                  for (final f in fornecedores) DropdownMenuItem(value: f.id, child: Text(f.nomeExibicao, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _fornecedorId = v),
              ),
            ),
            FilledButton.icon(
              onPressed: selecionados.isEmpty || _gerando ? null : _gerar,
              icon: const Icon(Icons.playlist_add_check),
              label: const Text('Gerar lista de compras'),
            ),
          ]),
          const SizedBox(height: 12),
          Card(
            child: Column(children: [
              for (final (i, s) in lista.indexed) ...[
                if (i > 0) const Divider(),
                CheckboxListTile(
                  value: selecionados.contains(s.produtoId),
                  onChanged: (v) => setState(() => v == true ? selecionados.add(s.produtoId) : selecionados.remove(s.produtoId)),
                  title: Text(s.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text([
                    'estoque ${formatarQuantidade(s.estoqueAtual)} de ${formatarQuantidade(s.estoqueMinimo)} ${s.unidadeSigla}',
                    if (s.fornecedor != null) s.fornecedor!,
                  ].join(' · ')),
                  secondary: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('comprar', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    Text(
                      s.embalagem != null
                          ? '${formatarQuantidade(s.sugeridoEmbalagens)} × ${s.embalagem}'
                          : '${formatarQuantidade(s.sugerido)} ${s.unidadeSigla}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppCores.ambarEscuro),
                    ),
                  ]),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ]),
          ),
        ]);
      },
    );
  }
}

class _Listas extends ConsumerStatefulWidget {
  const _Listas();

  @override
  ConsumerState<_Listas> createState() => _ListasState();
}

class _ListasState extends ConsumerState<_Listas> {
  String? _status = 'RASCUNHO';

  @override
  Widget build(BuildContext context) {
    final compras = ref.watch(comprasProvider(_status));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(
        alignment: Alignment.centerLeft,
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'RASCUNHO', label: Text('Em aberto')),
            ButtonSegment(value: 'RECEBIDA', label: Text('Recebidas')),
            ButtonSegment(value: 'CANCELADA', label: Text('Canceladas')),
            ButtonSegment(value: '', label: Text('Todas')),
          ],
          selected: {_status ?? ''},
          onSelectionChanged: (s) => setState(() => _status = s.first.isEmpty ? null : s.first),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: compras.when(
          loading: () => const Carregando(),
          error: (e, _) => ErroView(mensagem: mensagemDeErro(e)),
          data: (p) => p.conteudo.isEmpty
              ? const EstadoVazio(icone: Icons.list_alt, titulo: 'Nenhuma lista de compras')
              : Column(children: [
                  for (final (i, c) in p.conteudo.indexed) ...[
                    if (i > 0) const Divider(),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      onTap: () => context.go('/compras/${c.id}'),
                      leading: const CircleAvatar(child: Icon(Icons.shopping_cart_outlined)),
                      title: Text('Lista nº ${c.numero}${c.fornecedor == null ? '' : ' · ${c.fornecedor}'}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${formatarDataHora(c.criadaEm)} · ${c.quantidadeItens} item(ns)'),
                      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(formatarMoeda(c.total), style: const TextStyle(fontWeight: FontWeight.w800)),
                        Etiqueta(
                          c.status.rotulo,
                          cor: switch (c.status) {
                            StatusCompra.rascunho => AppCores.ambarEscuro,
                            StatusCompra.recebida => AppCores.sucesso,
                            StatusCompra.cancelada => Colors.grey.shade600,
                          },
                        ),
                      ]),
                    ),
                  ],
                ]),
        ),
      ),
    ]);
  }
}
