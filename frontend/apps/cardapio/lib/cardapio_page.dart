import 'package:core/core.dart';
import 'package:flutter/material.dart';

import 'dados.dart';
import 'pedido_page.dart';

const _corTextoSuave = Color(0xFFB8AC9C);

class CardapioPage extends StatefulWidget {
  const CardapioPage({super.key});

  @override
  State<CardapioPage> createState() => _CardapioPageState();
}

class _CardapioPageState extends State<CardapioPage> {
  final _carrinho = Carrinho();
  late Future<Cardapio> _cardapio = buscarCardapio();
  final _secoes = <String, GlobalKey>{};
  String? _categoriaAtiva;
  List<Acompanhamento> _meusPedidos = const [];

  @override
  void initState() {
    super.initState();
    _carregarMeusPedidos();
  }

  @override
  void dispose() {
    _carrinho.dispose();
    super.dispose();
  }

  /// Pedidos feitos neste celular que ainda estão em andamento (atalho para acompanhar).
  Future<void> _carregarMeusPedidos() async {
    final ids = await Memoria.pedidos();
    final ativos = <Acompanhamento>[];
    for (final id in ids) {
      try {
        final p = await buscarPedido(id);
        if (!p.finalizado) ativos.add(p);
      } catch (_) {
        // pedido antigo ou servidor indisponível: ignora
      }
    }
    if (mounted) setState(() => _meusPedidos = ativos);
  }

  void _recarregar() => setState(() => _cardapio = buscarCardapio());

  void _irPara(String categoriaId) {
    setState(() => _categoriaAtiva = categoriaId);
    final contexto = _secoes[categoriaId]?.currentContext;
    if (contexto != null) {
      Scrollable.ensureVisible(contexto, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    }
  }

  Future<void> _abrirProduto(ProdutoCardapio p, bool aberto) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProdutoSheet(produto: p, carrinho: _carrinho, aberto: aberto),
    );
  }

  Future<void> _abrirCarrinho() async {
    final pedido = await showModalBottomSheet<Acompanhamento>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CarrinhoSheet(carrinho: _carrinho),
    );
    if (pedido == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PedidoPage(pedidoId: pedido.id, inicial: pedido)));
    _carregarMeusPedidos();
    _recarregar();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Cardapio>(
      future: _cardapio,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.wifi_off, size: 48, color: _corTextoSuave),
                  const SizedBox(height: 12),
                  Text(mensagemDeErro(snap.error!), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(onPressed: _recarregar, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
                ]),
              ),
            ),
          );
        }
        return _conteudo(snap.data!);
      },
    );
  }

  Widget _conteudo(Cardapio c) {
    final tema = Theme.of(context);
    final local = localDoQrCode();
    for (final cat in c.categorias) {
      _secoes.putIfAbsent(cat.id, GlobalKey.new);
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        toolbarHeight: 72,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.nomeBar, style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          Text(local == null ? 'Cardápio' : 'Cardápio · $local',
              style: tema.textTheme.bodySmall?.copyWith(color: AppCores.ambar)),
        ]),
        actions: [
          IconButton(tooltip: 'Atualizar', onPressed: _recarregar, icon: const Icon(Icons.refresh)),
          const SizedBox(width: 8),
        ],
        bottom: c.categorias.length < 2
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    children: [
                      for (final cat in c.categorias)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(cat.nome),
                            selected: _categoriaAtiva == cat.id,
                            showCheckmark: false,
                            labelStyle: TextStyle(
                              color: _categoriaAtiva == cat.id ? AppCores.sobreAmbar : null,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (_) => _irPara(cat.id),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _recarregar();
          await _carregarMeusPedidos();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final p in _meusPedidos) _AvisoPedido(pedido: p, aoAbrir: () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PedidoPage(pedidoId: p.id)));
                  _carregarMeusPedidos();
                }),
                if (!c.aberto)
                  const _Aviso(
                    icone: Icons.schedule,
                    texto: 'No momento não estamos recebendo pedidos pelo cardápio. Chame um atendente.',
                  ),
                if (c.categorias.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Text('O cardápio ainda está sendo montado.',
                        textAlign: TextAlign.center, style: TextStyle(color: _corTextoSuave)),
                  ),
                for (final cat in c.categorias) ...[
                  Padding(
                    key: _secoes[cat.id],
                    padding: const EdgeInsets.only(top: 20, bottom: 10),
                    child: Text(cat.nome, style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  for (final p in cat.produtos) ...[
                    ListenableBuilder(
                      listenable: _carrinho,
                      builder: (_, _) => _CartaoProduto(
                        produto: p,
                        noCarrinho: _carrinho.quantidadeDe(p.id),
                        aoTocar: () => _abrirProduto(p, c.aberto),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ]),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: ListenableBuilder(
        listenable: _carrinho,
        builder: (_, _) => _carrinho.vazio
            ? const SizedBox.shrink()
            : ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FilledButton(
                    onPressed: _abrirCarrinho,
                    style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 58)),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppCores.sobreAmbar,
                        child: Text('${_carrinho.quantidade}',
                            style: const TextStyle(color: AppCores.ambar, fontSize: 13, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Ver pedido')),
                      Text(formatarMoeda(_carrinho.total)),
                    ]),
                  ),
                ),
              ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icone, required this.texto});

  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppCores.ambar.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppCores.ambar.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(icone, color: AppCores.ambar),
        const SizedBox(width: 12),
        Expanded(child: Text(texto)),
      ]),
    );
  }
}

class _AvisoPedido extends StatelessWidget {
  const _AvisoPedido({required this.pedido, required this.aoAbrir});

  final Acompanhamento pedido;
  final VoidCallback aoAbrir;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: AppCores.ambar,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: aoAbrir,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const Icon(Icons.receipt_long, color: AppCores.sobreAmbar),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Pedido nº ${pedido.numero}: ${pedido.etapa.titulo}',
                    style: const TextStyle(color: AppCores.sobreAmbar, fontWeight: FontWeight.w700)),
              ),
              const Text('Acompanhar', style: TextStyle(color: AppCores.sobreAmbar)),
              const Icon(Icons.chevron_right, color: AppCores.sobreAmbar),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Foto extends StatelessWidget {
  const _Foto({required this.url, required this.tamanho});

  final String? url;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final vazio = Container(
      width: tamanho,
      height: tamanho,
      color: const Color(0xFF2E2720),
      child: const Icon(Icons.local_bar_outlined, color: Color(0xFF6B5D4F)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: url == null
          ? vazio
          : Image.network(url!, width: tamanho, height: tamanho, fit: BoxFit.cover, errorBuilder: (_, _, _) => vazio),
    );
  }
}

class _CartaoProduto extends StatelessWidget {
  const _CartaoProduto({required this.produto, required this.noCarrinho, required this.aoTocar});

  final ProdutoCardapio produto;
  final int noCarrinho;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final p = produto;
    return Opacity(
      opacity: p.esgotado ? 0.5 : 1,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: p.esgotado ? null : aoTocar,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.nome, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  if (p.descricao != null && p.descricao!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(p.descricao!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _corTextoSuave, fontSize: 13)),
                  ],
                  const SizedBox(height: 8),
                  Row(children: [
                    Text(formatarMoeda(p.preco),
                        style: const TextStyle(color: AppCores.ambar, fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(width: 8),
                    if (p.esgotado)
                      const Text('Esgotado', style: TextStyle(color: Color(0xFFF87171), fontWeight: FontWeight.w600)),
                    if (noCarrinho > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppCores.ambar, borderRadius: BorderRadius.circular(20)),
                        child: Text('$noCarrinho no pedido',
                            style: const TextStyle(color: AppCores.sobreAmbar, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                  ]),
                ]),
              ),
              const SizedBox(width: 12),
              _Foto(url: p.imagemUrl, tamanho: 84),
            ]),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Produto: quantidade e observação
// =============================================================================

class _ProdutoSheet extends StatefulWidget {
  const _ProdutoSheet({required this.produto, required this.carrinho, required this.aberto});

  final ProdutoCardapio produto;
  final Carrinho carrinho;
  final bool aberto;

  @override
  State<_ProdutoSheet> createState() => _ProdutoSheetState();
}

class _ProdutoSheetState extends State<_ProdutoSheet> {
  int _quantidade = 1;
  final _obs = TextEditingController();

  @override
  void dispose() {
    _obs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.produto;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (p.imagemUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(p.imagemUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(p.nome, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          if (p.descricao != null && p.descricao!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(p.descricao!, style: const TextStyle(color: _corTextoSuave)),
          ],
          const SizedBox(height: 8),
          Text(formatarMoeda(p.preco),
              style: const TextStyle(color: AppCores.ambar, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(
            controller: _obs,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Observação (opcional)', hintText: 'Ex.: sem cebola, bem gelada'),
          ),
          const SizedBox(height: 8),
          Row(children: [
            _BotaoQuantidade(
              icone: Icons.remove,
              aoTocar: _quantidade > 1 ? () => setState(() => _quantidade--) : null,
            ),
            SizedBox(
              width: 48,
              child: Text('$_quantidade',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            _BotaoQuantidade(
              icone: Icons.add,
              aoTocar: _quantidade < 50 ? () => setState(() => _quantidade++) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton(
                onPressed: widget.aberto
                    ? () {
                        widget.carrinho.adicionar(p, _quantidade, _obs.text);
                        Navigator.pop(context);
                      }
                    : null,
                child: Text(widget.aberto ? 'Adicionar · ${formatarMoeda(p.preco * _quantidade)}' : 'Pedidos fechados'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _BotaoQuantidade extends StatelessWidget {
  const _BotaoQuantidade({required this.icone, this.aoTocar});

  final IconData icone;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      onPressed: aoTocar,
      icon: Icon(icone),
      style: IconButton.styleFrom(side: const BorderSide(color: Color(0xFF3A322A))),
    );
  }
}

// =============================================================================
// Carrinho e envio
// =============================================================================

class _CarrinhoSheet extends StatefulWidget {
  const _CarrinhoSheet({required this.carrinho});

  final Carrinho carrinho;

  @override
  State<_CarrinhoSheet> createState() => _CarrinhoSheetState();
}

class _CarrinhoSheetState extends State<_CarrinhoSheet> {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _local = TextEditingController(text: localDoQrCode() ?? '');
  final _obs = TextEditingController();
  final _localFixo = localDoQrCode() != null;
  bool _enviando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    Memoria.nome().then((n) {
      if (n != null && _nome.text.isEmpty && mounted) _nome.text = n;
    });
  }

  @override
  void dispose() {
    _nome.dispose();
    _local.dispose();
    _obs.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_form.currentState!.validate() || _enviando) return;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      final pedido = await enviarPedido(widget.carrinho,
          nome: _nome.text.trim(), local: _local.text.trim(), observacao: _obs.text);
      await Memoria.salvarNome(_nome.text.trim());
      await Memoria.lembrarPedido(pedido.id);
      widget.carrinho.limpar();
      if (mounted) Navigator.pop(context, pedido);
    } catch (e) {
      // A chave do carrinho é mantida: tentar de novo não duplica o pedido se o primeiro chegou.
      if (mounted) setState(() => _erro = mensagemDeErro(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.carrinho;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          if (c.vazio) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text('Seu pedido está vazio.', textAlign: TextAlign.center),
            );
          }
          return SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Seu pedido', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                for (final i in c.itens)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(i.produto.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (i.observacao != null)
                            Text(i.observacao!, style: const TextStyle(color: _corTextoSuave, fontSize: 13)),
                          Text(formatarMoeda(i.total), style: const TextStyle(color: AppCores.ambar)),
                        ]),
                      ),
                      _BotaoQuantidade(icone: i.quantidade == 1 ? Icons.delete_outline : Icons.remove, aoTocar: () => c.alterar(i, -1)),
                      SizedBox(
                        width: 36,
                        child: Text('${i.quantidade}',
                            textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      _BotaoQuantidade(icone: Icons.add, aoTocar: i.quantidade < 50 ? () => c.alterar(i, 1) : null),
                    ]),
                  ),
                const Divider(height: 24),
                Row(children: [
                  const Expanded(child: Text('Total', style: TextStyle(fontSize: 18))),
                  Text(formatarMoeda(c.total), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 4),
                const Text('O pagamento é feito no local, com o atendente.',
                    style: TextStyle(color: _corTextoSuave, fontSize: 13)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nome,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Seu nome'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe seu nome' : null,
                ),
                TextFormField(
                  controller: _local,
                  maxLength: 80,
                  readOnly: _localFixo,
                  decoration: InputDecoration(
                    labelText: 'Mesa ou local',
                    hintText: 'Ex.: Mesa 5, Balcão',
                    prefixIcon: const Icon(Icons.place_outlined),
                    helperText: _localFixo ? 'Identificado pelo QR Code' : null,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a mesa ou o local' : null,
                ),
                TextFormField(
                  controller: _obs,
                  maxLength: 500,
                  decoration: const InputDecoration(labelText: 'Observação geral (opcional)'),
                ),
                if (_erro != null) ...[
                  Text(_erro!, style: const TextStyle(color: Color(0xFFF87171))),
                  const SizedBox(height: 8),
                ],
                FilledButton(
                  onPressed: _enviando ? null : _enviar,
                  child: _enviando
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : Text('Enviar pedido · ${formatarMoeda(c.total)}'),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}
