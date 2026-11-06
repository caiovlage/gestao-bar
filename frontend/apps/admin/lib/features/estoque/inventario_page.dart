import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../produtos/produtos.dart';
import 'estoque.dart';

/// Contagem de um inventário (aberto) ou consulta do resultado (concluído/cancelado).
class InventarioPage extends ConsumerWidget {
  const InventarioPage({super.key, required this.inventarioId});

  final String inventarioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventario = ref.watch(inventarioProvider(inventarioId));
    return inventario.when(
      loading: () => const Carregando(),
      error: (e, _) => ErroView(
        mensagem: mensagemDeErro(e),
        aoTentarNovamente: () => ref.invalidate(inventarioProvider(inventarioId)),
      ),
      // A chave recria o formulário quando o status muda (ex.: aberto → concluído).
      data: (inv) => _Inventario(key: ValueKey('${inv.id}-${inv.status.api}'), inventario: inv),
    );
  }
}

enum _Filtro { todos, naoContados, comDiferenca }

class _Inventario extends ConsumerStatefulWidget {
  const _Inventario({super.key, required this.inventario});

  final InventarioDetalhe inventario;

  @override
  ConsumerState<_Inventario> createState() => _InventarioState();
}

class _InventarioState extends ConsumerState<_Inventario> {
  late final Map<String, TextEditingController> _contagens = {
    for (final item in widget.inventario.itens)
      item.produtoId: TextEditingController(text: formatarParaEdicao(item.quantidadeContada)),
  };
  final _busca = TextEditingController();
  _Filtro _filtro = _Filtro.todos;
  bool _ocupado = false;
  bool _alterado = false;

  InventarioDetalhe get _inv => widget.inventario;

  @override
  void dispose() {
    for (final c in _contagens.values) {
      c.dispose();
    }
    _busca.dispose();
    super.dispose();
  }

  void _voltar() {
    ref.read(secaoEstoqueProvider.notifier).mudar(SecaoEstoque.inventarios);
    context.go('/estoque');
  }

  /// Valores digitados (vazio = não contado). Retorna null se algum valor for inválido.
  Map<String, num?>? _lerContagens() {
    final valores = <String, num?>{};
    for (final e in _contagens.entries) {
      final texto = e.value.text.trim();
      if (texto.isEmpty) {
        valores[e.key] = null;
        continue;
      }
      final n = lerDecimal(texto);
      if (n == null || n < 0) {
        final nome = _inv.itens.firstWhere((i) => i.produtoId == e.key).produtoNome;
        mostrarErro(context, 'Quantidade inválida para $nome.');
        return null;
      }
      valores[e.key] = n;
    }
    return valores;
  }

  Future<bool> _salvar({bool avisar = true}) async {
    final valores = _lerContagens();
    if (valores == null) return false;
    setState(() => _ocupado = true);
    try {
      await ref.read(estoqueRepositoryProvider).salvarContagens(_inv.id, valores);
      ref.invalidate(inventarioProvider(_inv.id));
      ref.invalidate(inventariosProvider);
      _alterado = false;
      if (avisar && mounted) mostrarSucesso(context, 'Contagem salva.');
      return true;
    } catch (e) {
      if (mounted) mostrarErro(context, e);
      return false;
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _concluir() async {
    if (!await _salvar(avisar: false)) return;
    final atual = await ref.read(estoqueRepositoryProvider).inventario(_inv.id);
    if (!mounted) return;
    final naoContados = atual.totalItens - atual.itensContados;
    final ok = await confirmar(
      context,
      titulo: 'Concluir inventário',
      mensagem: '${atual.itensContados} item(ns) contado(s), ${atual.itensComDiferenca} com diferença.\n'
          '${naoContados > 0 ? '$naoContados item(ns) não contado(s) serão ignorados (estoque mantido).\n' : ''}'
          '\nO estoque dos itens com diferença será ajustado para a quantidade contada. '
          'Essa operação não pode ser desfeita.',
      acao: 'Concluir e ajustar',
    );
    if (!ok) return;
    setState(() => _ocupado = true);
    try {
      await ref.read(estoqueRepositoryProvider).concluirInventario(_inv.id, null);
      ref.invalidate(inventarioProvider(_inv.id));
      ref.invalidate(inventariosProvider);
      ref.invalidate(posicaoEstoqueProvider);
      ref.invalidate(resumoEstoqueProvider);
      ref.invalidate(movimentacoesProvider);
      ref.invalidate(produtosPaginaProvider);
      if (mounted) mostrarSucesso(context, 'Inventário concluído e estoque ajustado.');
    } catch (e) {
      if (mounted) mostrarErro(context, e);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _cancelar() async {
    final ok = await confirmar(context,
        titulo: 'Cancelar inventário',
        mensagem: 'O inventário será cancelado e nenhum ajuste será feito no estoque.',
        acao: 'Cancelar inventário',
        perigoso: true);
    if (!ok) return;
    try {
      await ref.read(estoqueRepositoryProvider).cancelarInventario(_inv.id, null);
      ref.invalidate(inventarioProvider(_inv.id));
      ref.invalidate(inventariosProvider);
      if (mounted) mostrarSucesso(context, 'Inventário cancelado.');
    } catch (e) {
      if (mounted) mostrarErro(context, e);
    }
  }

  List<ItemInventario> get _itensFiltrados {
    final termo = _busca.text.trim().toLowerCase();
    return _inv.itens.where((i) {
      if (termo.isNotEmpty && !i.produtoNome.toLowerCase().contains(termo)) return false;
      return switch (_filtro) {
        _Filtro.todos => true,
        _Filtro.naoContados => i.quantidadeContada == null,
        _Filtro.comDiferenca => i.diferenca != null && i.diferenca != 0,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final aberto = _inv.aberto;
    final itens = _itensFiltrados;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CabecalhoPagina(
          titulo: _inv.descricao,
          subtitulo: [
            _inv.status.rotulo,
            _inv.categoria ?? 'Todas as categorias',
            'aberto em ${formatarDataHora(_inv.criadoEm)}',
            if (_inv.concluidoEm != null) 'concluído em ${formatarDataHora(_inv.concluidoEm)}',
          ].join(' · '),
          acoes: [
            OutlinedButton.icon(onPressed: _voltar, icon: const Icon(Icons.arrow_back), label: const Text('Voltar')),
            if (aberto) ...[
              OutlinedButton(
                onPressed: _ocupado ? null : _cancelar,
                style: OutlinedButton.styleFrom(foregroundColor: AppCores.perigo),
                child: const Text('Cancelar inventário'),
              ),
              OutlinedButton.icon(
                onPressed: _ocupado ? null : () => _salvar(),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Salvar contagem'),
              ),
              FilledButton.icon(
                onPressed: _ocupado ? null : _concluir,
                icon: const Icon(Icons.check),
                label: const Text('Concluir'),
              ),
            ],
          ],
        ),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _Indicador('Itens', '${_inv.totalItens}'),
          _Indicador('Contados', '${_inv.itensContados}'),
          _Indicador('Com diferença', '${_inv.itensComDiferenca}',
              cor: _inv.itensComDiferenca > 0 ? AppCores.alerta : null),
        ]),
        if (aberto)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Digite a quantidade física encontrada. Deixe em branco o que não foi contado. '
              'As diferenças aparecem depois de salvar e são calculadas sobre o saldo no momento da conclusão.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                controller: _busca,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar produto'),
              ),
            ),
            SegmentedButton<_Filtro>(
              segments: const [
                ButtonSegment(value: _Filtro.todos, label: Text('Todos')),
                ButtonSegment(value: _Filtro.naoContados, label: Text('Não contados')),
                ButtonSegment(value: _Filtro.comDiferenca, label: Text('Com diferença')),
              ],
              selected: {_filtro},
              onSelectionChanged: (s) => setState(() => _filtro = s.first),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: itens.isEmpty
              ? const EstadoVazio(icone: Icons.search_off, titulo: 'Nenhum item neste filtro')
              : Column(children: [
                  for (final (i, item) in itens.indexed) ...[
                    if (i > 0) const Divider(),
                    _LinhaItem(
                      item: item,
                      controller: _contagens[item.produtoId]!,
                      editavel: aberto,
                      aoAlterar: () {
                        if (!_alterado) setState(() => _alterado = true);
                      },
                    ),
                  ],
                ]),
        ),
        if (aberto && _alterado)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Há contagens não salvas.', style: TextStyle(color: Colors.grey.shade600)),
          ),
      ],
    );
  }
}

class _Indicador extends StatelessWidget {
  const _Indicador(this.titulo, this.valor, {this.cor});

  final String titulo;
  final String valor;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            Text(valor, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: cor)),
          ]),
        ),
      ),
    );
  }
}

class _LinhaItem extends StatelessWidget {
  const _LinhaItem({required this.item, required this.controller, required this.editavel, required this.aoAlterar});

  final ItemInventario item;
  final TextEditingController controller;
  final bool editavel;
  final VoidCallback aoAlterar;

  @override
  Widget build(BuildContext context) {
    final dif = item.diferenca;
    final corDif = dif == null || dif == 0 ? Colors.grey.shade600 : (dif > 0 ? AppCores.sucesso : AppCores.perigo);
    final textoDif = dif == null
        ? '—'
        : '${dif > 0 ? '+' : ''}${formatarQuantidade(dif)} ${item.unidadeSigla}'
            '${item.valorDiferenca != null && dif != 0 ? '  (${formatarMoeda(item.valorDiferenca)})' : ''}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 8,
        children: [
          SizedBox(
            width: 260,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.produtoNome, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                '${item.categoria ?? 'Sem categoria'} · sistema: '
                '${formatarQuantidade(item.quantidadeSistema)} ${item.unidadeSigla}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ]),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 150,
              child: editavel
                  ? TextField(
                      controller: controller,
                      onChanged: (_) => aoAlterar(),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: 'Contado', suffixText: item.unidadeSigla, isDense: true),
                    )
                  : Text(
                      item.quantidadeContada == null
                          ? 'não contado'
                          : 'contado: ${formatarQuantidade(item.quantidadeContada)} ${item.unidadeSigla}',
                    ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 170,
              child: Text(textoDif,
                  textAlign: TextAlign.right, style: TextStyle(color: corDif, fontWeight: FontWeight.w600)),
            ),
          ]),
        ],
      ),
    );
  }
}
