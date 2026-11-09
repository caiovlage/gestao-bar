import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/widgets/paginacao.dart';
import '../caixa/caixa.dart';
import 'comandas.dart';

/// Comandas (contas abertas): o cliente vai consumindo e paga no fim.
class ComandasPage extends ConsumerStatefulWidget {
  const ComandasPage({super.key});

  @override
  ConsumerState<ComandasPage> createState() => _ComandasPageState();
}

class _ComandasPageState extends ConsumerState<ComandasPage> {
  bool _historico = false;

  Future<void> _abrir() async {
    final comanda = await showDialog<Comanda>(context: context, builder: (_) => const DialogoComanda());
    if (comanda == null || !mounted) return;
    ref.invalidate(comandasAbertasProvider);
    context.go('/comandas/${comanda.id}');
  }

  @override
  Widget build(BuildContext context) {
    final caixa = ref.watch(caixaAtualProvider);
    final caixaFechado = caixa.hasValue && caixa.value == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CabecalhoPagina(
          titulo: 'Comandas',
          subtitulo: 'Contas abertas: lance o consumo e feche a conta no pagamento',
          acoes: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Abertas'), icon: Icon(Icons.receipt_outlined)),
                ButtonSegment(value: true, label: Text('Histórico'), icon: Icon(Icons.history)),
              ],
              selected: {_historico},
              onSelectionChanged: (s) => setState(() => _historico = s.first),
            ),
            FilledButton.icon(
              onPressed: caixaFechado ? null : _abrir,
              icon: const Icon(Icons.add),
              label: const Text('Abrir comanda'),
            ),
          ],
        ),
        if (caixaFechado)
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_outline, color: AppCores.alerta),
              title: const Text('O caixa está fechado'),
              subtitle: const Text('As comandas pertencem ao caixa: abra o caixa para abrir uma comanda.'),
              trailing: TextButton(onPressed: () => context.go('/caixa'), child: const Text('Ir ao caixa')),
            ),
          ),
        if (caixaFechado) const SizedBox(height: 12),
        if (_historico) const _Historico() else const _Abertas(),
      ],
    );
  }
}

class _Abertas extends ConsumerWidget {
  const _Abertas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abertas = ref.watch(comandasAbertasProvider);
    return abertas.when(
      loading: () => const Card(child: Carregando()),
      error: (e, _) => Card(
        child: ErroView(mensagem: mensagemDeErro(e), aoTentarNovamente: () => ref.invalidate(comandasAbertasProvider)),
      ),
      data: (lista) {
        if (lista.isEmpty) {
          return const Card(
            child: EstadoVazio(
              icone: Icons.receipt_outlined,
              titulo: 'Nenhuma comanda aberta',
              descricao: 'Abra uma comanda quando o cliente for consumir e pagar no fim.',
            ),
          );
        }
        final total = lista.fold<num>(0, (s, c) => s + c.total);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('${lista.length} comanda(s) aberta(s) · ${formatarMoeda(total)} a receber',
                style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
          ),
          GradeResponsiva(
            larguraItem: 260,
            children: [for (final c in lista) _CartaoComanda(comanda: c)],
          ),
        ]);
      },
    );
  }
}

class _CartaoComanda extends StatelessWidget {
  const _CartaoComanda({required this.comanda});

  final Comanda comanda;

  @override
  Widget build(BuildContext context) {
    final c = comanda;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/comandas/${c.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('nº ${c.numero}', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(_tempo(c.abertaEm), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ]),
            const SizedBox(height: 4),
            Text(c.clienteNome,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            if (c.local != null)
              Text(c.local!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 10),
            Row(children: [
              Text('${formatarQuantidade(c.quantidadeItens)} item(ns)', style: TextStyle(color: Colors.grey.shade600)),
              const Spacer(),
              FittedBox(
                child: Text(formatarMoeda(c.total),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppCores.ambarEscuro)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  static String _tempo(DateTime? desde) {
    if (desde == null) return '';
    final min = DateTime.now().difference(desde).inMinutes;
    if (min < 1) return 'agora';
    if (min < 60) return 'há $min min';
    return 'há ${min ~/ 60}h${(min % 60).toString().padLeft(2, '0')}';
  }
}

class _Historico extends ConsumerWidget {
  const _Historico();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagina = ref.watch(historicoComandasProvider);
    return Card(
      child: pagina.when(
        loading: () => const Carregando(),
        error: (e, _) => ErroView(mensagem: mensagemDeErro(e), aoTentarNovamente: () => ref.invalidate(historicoComandasProvider)),
        data: (p) => p.conteudo.isEmpty
            ? const EstadoVazio(icone: Icons.history, titulo: 'Nenhuma comanda fechada ainda')
            : Column(children: [
                for (final c in p.conteudo) ...[
                  ListTile(
                    onTap: () => context.go('/comandas/${c.id}'),
                    leading: Icon(
                      c.status == StatusComanda.fechada ? Icons.check_circle_outline : Icons.cancel_outlined,
                      color: c.status == StatusComanda.fechada ? AppCores.sucesso : AppCores.perigo,
                    ),
                    title: Text('nº ${c.numero} · ${c.clienteNome}${c.local == null ? '' : ' · ${c.local}'}'),
                    subtitle: Text(c.status == StatusComanda.fechada
                        ? 'Fechada em ${formatarDataHora(c.fechadaEm)}'
                        : 'Cancelada em ${formatarDataHora(c.canceladaEm)}: ${c.motivoCancelamento ?? ''}'),
                    trailing: Text(formatarMoeda(c.total), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  const Divider(height: 1),
                ],
                Paginacao(pagina: p, aoMudar: (n) => ref.read(paginaHistoricoComandasProvider.notifier).ir(n)),
              ]),
      ),
    );
  }
}

/// Abrir comanda (ou editar nome/local de uma aberta, se [comanda] for informada).
class DialogoComanda extends ConsumerStatefulWidget {
  const DialogoComanda({super.key, this.comanda});

  final Comanda? comanda;

  @override
  ConsumerState<DialogoComanda> createState() => _DialogoComandaState();
}

class _DialogoComandaState extends ConsumerState<DialogoComanda> {
  late final _nome = TextEditingController(text: widget.comanda?.clienteNome);
  late final _local = TextEditingController(text: widget.comanda?.local);
  late final _obs = TextEditingController(text: widget.comanda?.observacao);
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _nome.dispose();
    _local.dispose();
    _obs.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final nome = _nome.text.trim();
    if (nome.isEmpty) {
      setState(() => _erro = 'Informe o nome do cliente.');
      return;
    }
    String? opcional(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      final repo = ref.read(comandasRepositoryProvider);
      final c = widget.comanda == null
          ? await repo.abrir(nome: nome, local: opcional(_local), observacao: opcional(_obs))
          : await repo.alterar(widget.comanda!.id, nome: nome, local: opcional(_local), observacao: opcional(_obs));
      if (mounted) Navigator.pop(context, c);
    } catch (e) {
      setState(() => _erro = mensagemDeErro(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.comanda == null ? 'Abrir comanda' : 'Comanda nº ${widget.comanda!.numero}'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _nome,
            autofocus: true,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nome do cliente *'),
          ),
          TextField(
            controller: _local,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Mesa ou local (opcional)', hintText: 'Ex.: Mesa 4, Bloco 3 · Apto 710'),
          ),
          TextField(
            controller: _obs,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Observação (opcional)'),
            onSubmitted: (_) => _salvar(),
          ),
          if (_erro != null) Text(_erro!, style: const TextStyle(color: AppCores.perigo)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _salvando ? null : _salvar,
          child: Text(widget.comanda == null ? 'Abrir comanda' : 'Salvar'),
        ),
      ],
    );
  }
}
