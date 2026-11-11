import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/widgets/paginacao.dart';
import '../caixa/caixa.dart';
import '../estoque/estoque.dart';
import '../vendas/vendas.dart';
import '../notificacoes/notificacoes.dart';
import 'pedidos.dart';

/// Painel de pedidos do cardápio digital: kanban atualizado a cada 10 segundos.
class PedidosPage extends ConsumerStatefulWidget {
  const PedidosPage({super.key});

  @override
  ConsumerState<PedidosPage> createState() => _PedidosPageState();
}

class _PedidosPageState extends ConsumerState<PedidosPage> {
  Timer? _timer;
  bool _historico = false;
  Set<String>? _conhecidos;
  final _novos = <String>{};

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_historico) ref.invalidate(pedidosEmAndamentoProvider);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Destaca os pedidos que chegaram desde a última atualização.
  void _detectarNovos(List<Pedido> pedidos) {
    final ids = pedidos.map((p) => p.id).toSet();
    final anteriores = _conhecidos;
    _conhecidos = ids;
    if (anteriores == null) return;
    final chegaram = pedidos.where((p) => !anteriores.contains(p.id) && p.status == StatusPreparo.recebido).toList();
    if (chegaram.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _novos.addAll(chegaram.map((p) => p.id)));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: StatusPreparo.recebido.cor,
        content: Row(children: [
          const Icon(Icons.notifications_active, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(chegaram.length == 1
                ? 'Novo pedido nº ${chegaram.first.numero} — ${chegaram.first.local}'
                : '${chegaram.length} novos pedidos'),
          ),
        ]),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pedidosEmAndamentoProvider, (_, prox) {
      if (prox.hasValue) _detectarNovos(prox.value!);
    });
    final pedidos = ref.watch(pedidosEmAndamentoProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CabecalhoPagina(
          titulo: 'Pedidos',
          subtitulo: 'Pedidos do cardápio digital para entrega nos apartamentos. Atualiza sozinho a cada 10 s.',
          acoes: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Em andamento'), icon: Icon(Icons.view_kanban_outlined)),
                ButtonSegment(value: true, label: Text('Histórico'), icon: Icon(Icons.history)),
              ],
              selected: {_historico},
              onSelectionChanged: (s) => setState(() => _historico = s.first),
            ),
            const BotaoNotificacoes(),
            IconButton(
              tooltip: 'Atualizar',
              onPressed: () {
                ref.invalidate(pedidosEmAndamentoProvider);
                ref.invalidate(historicoPedidosProvider);
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const AvisoAtivarNotificacoes(),
        if (_historico)
          const _Historico()
        else
          pedidos.when(
            loading: () => const Carregando(),
            error: (e, _) => Card(
              child: ErroView(
                mensagem: mensagemDeErro(e),
                aoTentarNovamente: () => ref.invalidate(pedidosEmAndamentoProvider),
              ),
            ),
            data: (lista) => _Kanban(
              pedidos: lista,
              novos: _novos,
              aoVer: (id) => setState(() => _novos.remove(id)),
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// Kanban
// =============================================================================

class _Coluna {
  const _Coluna(this.titulo, this.icone, this.cor, this.filtro);
  final String titulo;
  final IconData icone;
  final Color cor;
  final bool Function(Pedido) filtro;
}

final _colunas = <_Coluna>[
  _Coluna('Novos', Icons.notifications_active_outlined, StatusPreparo.recebido.cor,
      (p) => p.status == StatusPreparo.recebido),
  _Coluna('Em preparo', Icons.soup_kitchen_outlined, StatusPreparo.emPreparo.cor,
      (p) => p.status == StatusPreparo.aceito || p.status == StatusPreparo.emPreparo),
  _Coluna('Prontos para entrega', Icons.delivery_dining_outlined, StatusPreparo.pronto.cor, (p) => p.status == StatusPreparo.pronto),
  _Coluna('Entregues · aguardando pagamento', Icons.payments_outlined, StatusPreparo.entregue.cor,
      (p) => p.status == StatusPreparo.entregue),
];

class _Kanban extends StatelessWidget {
  const _Kanban({required this.pedidos, required this.novos, required this.aoVer});

  final List<Pedido> pedidos;
  final Set<String> novos;
  final ValueChanged<String> aoVer;

  @override
  Widget build(BuildContext context) {
    if (pedidos.isEmpty) {
      return const Card(
        child: EstadoVazio(
          icone: Icons.receipt_long_outlined,
          titulo: 'Nenhum pedido em andamento',
          descricao: 'Os pedidos feitos pelo cardápio digital aparecem aqui automaticamente.\n'
              'Envie o link do cardápio pelo WhatsApp (Configurações).',
        ),
      );
    }
    return LayoutBuilder(builder: (context, c) {
      final largo = c.maxWidth >= 1100;
      final colunas = [
        for (final col in _colunas)
          _ColunaKanban(
            coluna: col,
            pedidos: pedidos.where(col.filtro).toList(),
            novos: novos,
            aoVer: aoVer,
          ),
      ];
      if (ehCelular(context)) {
        // Celular: colunas empilhadas (as vazias ficam por último)
        final ordenadas = [...colunas.where((c) => c.pedidos.isNotEmpty), ...colunas.where((c) => c.pedidos.isEmpty)];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < ordenadas.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            ordenadas[i],
          ],
        ]);
      }
      if (largo) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < colunas.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: colunas[i]),
            ],
          ],
        );
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < colunas.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              SizedBox(width: 300, child: colunas[i]),
            ],
          ],
        ),
      );
    });
  }
}

class _ColunaKanban extends StatelessWidget {
  const _ColunaKanban({required this.coluna, required this.pedidos, required this.novos, required this.aoVer});

  final _Coluna coluna;
  final List<Pedido> pedidos;
  final Set<String> novos;
  final ValueChanged<String> aoVer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: coluna.cor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: coluna.cor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
            child: Row(children: [
              Icon(coluna.icone, size: 18, color: coluna.cor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(coluna.titulo,
                    style: TextStyle(fontWeight: FontWeight.w700, color: coluna.cor), overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: coluna.cor, borderRadius: BorderRadius.circular(20)),
                child: Text('${pedidos.length}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ]),
          ),
          if (pedidos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('—', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500)),
            ),
          for (final p in pedidos) ...[
            _CartaoPedido(pedido: p, novo: novos.contains(p.id), aoVer: () => aoVer(p.id)),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _CartaoPedido extends ConsumerStatefulWidget {
  const _CartaoPedido({required this.pedido, required this.novo, required this.aoVer});

  final Pedido pedido;
  final bool novo;
  final VoidCallback aoVer;

  @override
  ConsumerState<_CartaoPedido> createState() => _CartaoPedidoState();
}

class _CartaoPedidoState extends ConsumerState<_CartaoPedido> {
  bool _ocupado = false;

  Future<void> _executar(Future<Pedido> Function(PedidosRepository repo) acao, String sucesso) async {
    widget.aoVer();
    setState(() => _ocupado = true);
    try {
      await acao(ref.read(pedidosRepositoryProvider));
      ref.invalidate(pedidosEmAndamentoProvider);
      ref.invalidate(historicoPedidosProvider);
      ref.invalidate(posicaoEstoqueProvider);
      ref.invalidate(catalogoPdvProvider);
      if (mounted) mostrarSucesso(context, sucesso);
    } catch (e) {
      if (mounted) mostrarErro(context, e);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _cancelar() async {
    final p = widget.pedido;
    final motivo = await pedirMotivo(context,
        titulo: p.status == StatusPreparo.recebido ? 'Recusar pedido nº ${p.numero}' : 'Cancelar pedido nº ${p.numero}',
        dica: 'Ex.: produto acabou, cliente desistiu',
        acao: p.status == StatusPreparo.recebido ? 'Recusar' : 'Cancelar pedido');
    if (motivo == null) return;
    await _executar((r) => r.cancelar(p.id, motivo),
        p.status == StatusPreparo.recebido ? 'Pedido recusado.' : 'Pedido cancelado. Reserva de estoque liberada.');
  }

  Future<void> _receber() async {
    widget.aoVer();
    final pago = await showDialog<Pedido>(context: context, builder: (_) => PagamentoPedidoDialog(pedido: widget.pedido));
    if (pago == null) return;
    ref.invalidate(pedidosEmAndamentoProvider);
    ref.invalidate(historicoPedidosProvider);
    ref.invalidate(caixaAtualProvider);
    ref.invalidate(vendasProvider);
    ref.invalidate(posicaoEstoqueProvider);
    ref.invalidate(catalogoPdvProvider);
    if (mounted) mostrarSucesso(context, 'Venda do pedido nº ${pago.numero} concluída: já aparece em Vendas, Caixa e relatórios.');
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido;
    final tema = Theme.of(context);
    final proximo = p.status.proximo;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: widget.novo ? StatusPreparo.recebido.cor : Colors.grey.shade200,
          width: widget.novo ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.aoVer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Text('nº ${p.numero}', style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                if (widget.novo) const Etiqueta('NOVO', cor: Color(0xFF2563EB)),
                const Spacer(),
                Text(_tempo(p.criadoEm), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ]),
              const SizedBox(height: 4),
              // Endereço de entrega em destaque
              Row(children: [
                const Icon(Icons.apartment, size: 18, color: AppCores.ambarEscuro),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(p.local,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15), overflow: TextOverflow.ellipsis),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: Text(p.clienteNome, style: TextStyle(color: Colors.grey.shade700), overflow: TextOverflow.ellipsis),
              ),
              const Divider(height: 16),
              for (final i in p.itens)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${i.quantidade}× ${i.produtoNome}', style: const TextStyle(fontWeight: FontWeight.w500)),
                    if (i.observacao != null)
                      Text('  ↳ ${i.observacao}',
                          style: const TextStyle(color: AppCores.ambarEscuro, fontSize: 13, fontStyle: FontStyle.italic)),
                  ]),
                ),
              if (p.observacao != null)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppCores.fundo, borderRadius: BorderRadius.circular(8)),
                  child: Text('Obs.: ${p.observacao}', style: const TextStyle(fontSize: 13)),
                ),
              const SizedBox(height: 8),
              Row(children: [
                Text(formatarMoeda(p.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const Spacer(),
                if (p.pago)
                  const Etiqueta('Pago', cor: AppCores.sucesso, icone: Icons.check)
                else if (p.status != StatusPreparo.recebido)
                  const Etiqueta('A receber', cor: AppCores.alerta),
              ]),
              const SizedBox(height: 10),
              if (_ocupado)
                const LinearProgressIndicator()
              else
                Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.end, children: [
                  if (p.status == StatusPreparo.recebido) ...[
                    OutlinedButton(onPressed: _cancelar, child: const Text('Recusar')),
                    FilledButton.icon(
                      onPressed: () => _executar((r) => r.aceitar(p.id), 'Pedido nº ${p.numero} aceito.'),
                      icon: const Icon(Icons.check),
                      label: const Text('Aceitar'),
                    ),
                  ],
                  if (proximo != null)
                    FilledButton.tonal(
                      onPressed: () => _executar((r) => r.avancar(p.id, proximo.$1), 'Pedido nº ${p.numero}: ${proximo.$1.rotulo.toLowerCase()}.'),
                      child: Text(proximo.$2),
                    ),
                  if (p.podeReceber)
                    FilledButton.icon(
                      onPressed: _receber,
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Concluir venda'),
                    ),
                  if (p.status != StatusPreparo.recebido && !p.pago)
                    IconButton(
                      tooltip: 'Cancelar pedido',
                      onPressed: _cancelar,
                      icon: const Icon(Icons.cancel_outlined, color: AppCores.perigo),
                    ),
                ]),
            ],
          ),
        ),
      ),
    );
  }

  static String _tempo(DateTime? criado) {
    if (criado == null) return '';
    final min = DateTime.now().difference(criado).inMinutes;
    if (min < 1) return 'agora';
    if (min < 60) return 'há $min min';
    return formatarDataHora(criado).substring(11);
  }
}

/// Pede um motivo obrigatório (recusa/cancelamento). Retorna null se o usuário desistir.
Future<String?> pedirMotivo(BuildContext context,
    {required String titulo, required String dica, required String acao}) {
  final controle = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(titulo),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controle,
            autofocus: true,
            maxLength: 500,
            decoration: InputDecoration(labelText: 'Motivo', hintText: dica),
            onChanged: (_) => setState(() {}),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Voltar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppCores.perigo, foregroundColor: Colors.white),
            onPressed: controle.text.trim().isEmpty ? null : () => Navigator.pop(context, controle.text.trim()),
            child: Text(acao),
          ),
        ],
      ),
    ),
  );
}

// =============================================================================
// Pagamento
// =============================================================================

/// Registra o pagamento presencial do pedido: gera a venda no caixa aberto.
class PagamentoPedidoDialog extends ConsumerStatefulWidget {
  const PagamentoPedidoDialog({super.key, required this.pedido});

  final Pedido pedido;

  @override
  ConsumerState<PagamentoPedidoDialog> createState() => _PagamentoPedidoDialogState();
}

class _PagamentoPedidoDialogState extends ConsumerState<PagamentoPedidoDialog> {
  FormaPagamento _forma = FormaPagamento.pix;
  final _recebido = TextEditingController();
  final _desconto = TextEditingController();
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _recebido.dispose();
    _desconto.dispose();
    super.dispose();
  }

  num get _total {
    final d = lerDecimal(_desconto.text) ?? 0;
    final t = widget.pedido.total - d;
    return t < 0 ? 0 : t;
  }

  num? get _troco {
    if (_forma != FormaPagamento.dinheiro) return null;
    final r = lerDecimal(_recebido.text);
    return r == null ? null : r - _total;
  }

  Future<void> _confirmar() async {
    final troco = _troco;
    if (troco != null && troco < 0) {
      setState(() => _erro = 'O valor recebido é menor que o total.');
      return;
    }
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      final desconto = lerDecimal(_desconto.text);
      final pedido = await ref.read(pedidosRepositoryProvider).pagar(
            widget.pedido.id,
            _forma,
            valorRecebido: _forma == FormaPagamento.dinheiro ? lerDecimal(_recebido.text) : null,
            desconto: desconto == null || desconto == 0 ? null : desconto,
          );
      if (mounted) Navigator.pop(context, pedido);
    } catch (e) {
      setState(() => _erro = mensagemDeErro(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido;
    final caixa = ref.watch(caixaAtualProvider);
    final caixaFechado = caixa.hasValue && caixa.value == null;
    final troco = _troco;

    return AlertDialog(
      title: Text('Concluir venda · pedido nº ${p.numero}'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${p.local} · ${p.clienteNome}', style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 8),
              Text(formatarMoeda(_total),
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
              if (caixaFechado)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppCores.perigo.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.lock_outline, color: AppCores.perigo),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('O caixa está fechado. Abra o caixa para concluir a venda.')),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        context.go('/caixa');
                      },
                      child: const Text('Ir ao caixa'),
                    ),
                  ]),
                ),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final f in FormaPagamento.values)
                  ChoiceChip(
                    avatar: Icon(f.icone, size: 18),
                    label: Text(f.rotulo),
                    selected: _forma == f,
                    onSelected: (_) => setState(() => _forma = f),
                  ),
              ]),
              const SizedBox(height: 16),
              TextField(
                controller: _desconto,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Desconto (opcional)', prefixText: r'R$ '),
                onChanged: (_) => setState(() {}),
              ),
              if (_forma == FormaPagamento.dinheiro) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _recebido,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Valor recebido', prefixText: r'R$ '),
                  onChanged: (_) => setState(() {}),
                ),
                if (troco != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    troco < 0 ? 'Falta ${formatarMoeda(-troco)}' : 'Troco ${formatarMoeda(troco)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: troco < 0 ? AppCores.perigo : AppCores.ambarEscuro,
                    ),
                  ),
                ],
              ],
              if (_erro != null) ...[
                const SizedBox(height: 12),
                Text(_erro!, style: const TextStyle(color: AppCores.perigo)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton.icon(
          onPressed: _enviando || caixaFechado ? null : _confirmar,
          icon: const Icon(Icons.check),
          label: const Text('Concluir venda'),
        ),
      ],
    );
  }
}

// =============================================================================
// Histórico
// =============================================================================

class _Historico extends ConsumerWidget {
  const _Historico();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagina = ref.watch(historicoPedidosProvider);
    return Card(
      child: pagina.when(
        loading: () => const Carregando(),
        error: (e, _) => ErroView(
          mensagem: mensagemDeErro(e),
          aoTentarNovamente: () => ref.invalidate(historicoPedidosProvider),
        ),
        data: (p) {
          if (p.conteudo.isEmpty) {
            return const EstadoVazio(icone: Icons.history, titulo: 'Nenhum pedido registrado ainda');
          }
          return Column(children: [
            for (final pedido in p.conteudo) ...[
              ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: pedido.status.cor.withValues(alpha: 0.12),
                  child: Icon(pedido.status.icone, color: pedido.status.cor, size: 20),
                ),
                title: Text('nº ${pedido.numero} · ${pedido.local} · ${pedido.clienteNome}'),
                subtitle: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(formatarDataHora(pedido.criadoEm)),
                  Etiqueta(pedido.status.rotulo, cor: pedido.status.cor),
                  if (pedido.pago) const Etiqueta('Pago', cor: AppCores.sucesso),
                ]),
                trailing: Text(formatarMoeda(pedido.total), style: const TextStyle(fontWeight: FontWeight.w700)),
                childrenPadding: const EdgeInsets.fromLTRB(24, 0, 16, 12),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final i in pedido.itens)
                    Text('${i.quantidade}× ${i.produtoNome} — ${formatarMoeda(i.total)}'
                        '${i.observacao == null ? '' : ' (${i.observacao})'}'),
                  if (pedido.observacao != null) Text('Obs.: ${pedido.observacao}'),
                  if (pedido.motivoCancelamento != null)
                    Text('Motivo do cancelamento: ${pedido.motivoCancelamento}',
                        style: const TextStyle(color: AppCores.perigo)),
                  if (pedido.status != StatusPreparo.entregue && pedido.pago)
                    const Text('Pago antes da entrega.'),
                ],
              ),
              const Divider(height: 1),
            ],
            Paginacao(
              pagina: p,
              aoMudar: (n) => ref.read(paginaHistoricoPedidosProvider.notifier).ir(n),
            ),
          ]);
        },
      ),
    );
  }
}
