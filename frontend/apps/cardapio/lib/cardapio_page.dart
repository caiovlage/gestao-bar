import 'dart:async';
import 'dart:math' as math;

import 'package:core/core.dart' show Marca, VersaoMarca, formatarMoeda, mensagemDeErro;
import 'package:flutter/material.dart';

import 'dados.dart';
import 'pedido_page.dart';
import 'tema.dart';

/// Filtro rápido do topo: tudo, só promoções ou uma categoria.
sealed class _Filtro {
  const _Filtro();
}

class _Tudo extends _Filtro {
  const _Tudo();
}

class _Promocoes extends _Filtro {
  const _Promocoes();
}

class _Categoria extends _Filtro {
  const _Categoria(this.id);
  final String id;
}

enum _Ordem {
  relevancia('Sugestão do bar'),
  menorPreco('Menor preço'),
  maiorPreco('Maior preço'),
  nome('Nome (A–Z)');

  const _Ordem(this.rotulo);
  final String rotulo;
}

class CardapioPage extends StatefulWidget {
  const CardapioPage({super.key});

  @override
  State<CardapioPage> createState() => _CardapioPageState();
}

class _CardapioPageState extends State<CardapioPage> {
  final _carrinho = Carrinho();
  late Future<Cardapio> _cardapio = buscarCardapio();
  final _busca = TextEditingController();
  _Filtro _filtro = const _Tudo();
  _Ordem _ordem = _Ordem.relevancia;
  List<Acompanhamento> _meusPedidos = const [];

  @override
  void initState() {
    super.initState();
    _carregarMeusPedidos();
    _busca.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _carrinho.dispose();
    _busca.dispose();
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

  Future<void> _abrirProduto(ProdutoCardapio p, bool aberto) async {
    if (p.esgotado) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ProdutoSheet(produto: p, carrinho: _carrinho, aberto: aberto),
    );
  }

  Future<void> _abrirCarrinho() async {
    final pedido = await showModalBottomSheet<Acompanhamento>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CarrinhoSheet(carrinho: _carrinho),
    );
    if (pedido == null || !mounted) return;
    await Navigator.of(context).pushNamed(rotaPedido(pedido.id), arguments: pedido);
    _carregarMeusPedidos();
    _recarregar();
  }

  Future<void> _acompanhar(Acompanhamento p) async {
    await Navigator.of(context).pushNamed(rotaPedido(p.id), arguments: p);
    _carregarMeusPedidos();
  }

  /// Busca e filtros ativos: mostra a lista filtrada em vez da vitrine.
  bool get _filtrando => _busca.text.trim().isNotEmpty || _filtro is! _Tudo || _ordem != _Ordem.relevancia;

  List<ProdutoCardapio> _filtrados(Cardapio c) {
    final termo = _semAcento(_busca.text.trim().toLowerCase());
    var lista = c.produtos.where((p) {
      final passaFiltro = switch (_filtro) {
        _Tudo() => true,
        _Promocoes() => p.emPromocao,
        _Categoria(:final id) => p.categoriaId == id,
      };
      if (!passaFiltro) return false;
      if (termo.isEmpty) return true;
      return _semAcento('${p.nome} ${p.descricao ?? ''} ${p.categoria}'.toLowerCase()).contains(termo);
    }).toList();
    switch (_ordem) {
      case _Ordem.relevancia:
        break;
      case _Ordem.menorPreco:
        lista.sort((a, b) => a.preco.compareTo(b.preco));
      case _Ordem.maiorPreco:
        lista.sort((a, b) => b.preco.compareTo(a.preco));
      case _Ordem.nome:
        lista.sort((a, b) => _semAcento(a.nome.toLowerCase()).compareTo(_semAcento(b.nome.toLowerCase())));
    }
    // Esgotados sempre no fim
    lista = [...lista.where((p) => !p.esgotado), ...lista.where((p) => p.esgotado)];
    return lista;
  }

  void _limparFiltros() => setState(() {
        _busca.clear();
        _filtro = const _Tudo();
        _ordem = _Ordem.relevancia;
      });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Cardapio>(
      future: _cardapio,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: _Carregando());
        }
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.wifi_off, size: 48, color: Paleta.textoSuave),
                  const SizedBox(height: 12),
                  Text(mensagemDeErro(snap.error!), textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                      onPressed: _recarregar, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
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
    final maisPedidos = c.maisPedidos;
    final largura = MediaQuery.sizeOf(context).width;
    final margem = largura > 760 ? (largura - 720) / 2 : 16.0;

    Widget cartao(ProdutoCardapio p) => _LinhaProduto(
          produto: p,
          carrinho: _carrinho,
          maisPedido: maisPedidos.contains(p.id),
          aoTocar: () => _abrirProduto(p, c.aberto),
        );

    return Scaffold(
      body: RefreshIndicator(
        color: Paleta.verde,
        onRefresh: () async {
          _recarregar();
          await _carregarMeusPedidos();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _Cabecalho(aoAtualizar: _recarregar),
            SliverPersistentHeader(
              pinned: true,
              delegate: _BarraFiltros(
                busca: _busca,
                filtro: _filtro,
                ordem: _ordem,
                cardapio: c,
                margem: margem,
                aoFiltrar: (f) => setState(() => _filtro = f),
                aoOrdenar: (o) => setState(() => _ordem = o),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(margem, 4, margem, 0),
              sliver: SliverList.list(children: [
                for (final p in _meusPedidos) _AvisoPedido(pedido: p, aoAbrir: () => _acompanhar(p)),
                if (!c.aberto)
                  const _Aviso(
                    icone: Icons.nightlife_outlined,
                    texto: 'No momento não estamos recebendo pedidos. Tente novamente mais tarde.',
                  ),
              ]),
            ),
            if (c.categorias.isEmpty)
              const SliverFillRemaining(hasScrollBody: false, child: _CardapioVazio())
            else if (_filtrando)
              ..._resultados(c, margem, cartao)
            else ...[
              for (final (i, secao) in c.destaques.indexed)
                SliverToBoxAdapter(
                  child: i == 0
                      ? _VitrinePrincipal(
                          secao: secao,
                          margem: margem,
                          maisPedidos: maisPedidos,
                          aoTocar: (p) => _abrirProduto(p, c.aberto),
                        )
                      : _VitrineHorizontal(
                          secao: secao,
                          margem: margem,
                          maisPedidos: maisPedidos,
                          aoTocar: (p) => _abrirProduto(p, c.aberto),
                        ),
                ),
              for (final cat in c.categorias) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(margem, 32, margem, 6),
                    child: _TituloSecao(cat.nome, quantidade: cat.produtos.length),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: margem),
                  sliver: SliverList.separated(
                    itemCount: cat.produtos.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) => cartao(cat.produtos[i]),
                  ),
                ),
              ],
            ],
            const SliverToBoxAdapter(child: _Rodape()),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: ListenableBuilder(
        listenable: _carrinho,
        builder: (_, _) => _carrinho.vazio
            ? const SizedBox.shrink()
            : _BotaoCarrinho(carrinho: _carrinho, aoTocar: _abrirCarrinho),
      ),
    );
  }

  List<Widget> _resultados(Cardapio c, double margem, Widget Function(ProdutoCardapio) cartao) {
    final lista = _filtrados(c);
    final titulo = switch (_filtro) {
      _Promocoes() => 'Promoções',
      _Categoria(:final id) => c.categorias.where((k) => k.id == id).firstOrNull?.nome ?? 'Resultados',
      _Tudo() => _busca.text.trim().isEmpty ? 'Todos os itens' : 'Resultados',
    };
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(margem, 20, margem, 6),
          child: Row(children: [
            Expanded(child: _TituloSecao(titulo, quantidade: lista.length)),
            TextButton(onPressed: _limparFiltros, child: const Text('Limpar')),
          ]),
        ),
      ),
      if (lista.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
            child: Column(children: [
              const Icon(Icons.search_off, size: 44, color: Paleta.textoSuave),
              const SizedBox(height: 12),
              Text('Nada encontrado${_busca.text.trim().isEmpty ? '' : ' para "${_busca.text.trim()}"'}.',
                  textAlign: TextAlign.center, style: const TextStyle(color: Paleta.textoSuave)),
            ]),
          ),
        )
      else
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: margem),
          sliver: SliverList.separated(
            itemCount: lista.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) => cartao(lista[i]),
          ),
        ),
    ];
  }
}

String _semAcento(String texto) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const para = 'aaaaaeeeeiiiiooooouuuucn';
  final b = StringBuffer();
  for (final r in texto.runes) {
    final ch = String.fromCharCode(r);
    final i = de.indexOf(ch);
    b.write(i >= 0 ? para[i] : ch);
  }
  return b.toString();
}

// =============================================================================
// Cabeçalho
// =============================================================================

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.aoAtualizar});

  final VoidCallback aoAtualizar;

  static const _alturaAberta = 320.0;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: _alturaAberta,
      backgroundColor: Paleta.fundo,
      surfaceTintColor: Colors.transparent,
      actions: [
        IconButton(tooltip: 'Atualizar', onPressed: aoAtualizar, icon: const Icon(Icons.refresh, color: Paleta.verde)),
      ],
      flexibleSpace: LayoutBuilder(builder: (context, c) {
        final topo = MediaQuery.paddingOf(context).top;
        // 1 = totalmente aberto, 0 = recolhido
        final aberto = ((c.maxHeight - kToolbarHeight - topo) / (_alturaAberta - kToolbarHeight)).clamp(0.0, 1.0);
        return Stack(fit: StackFit.expand, children: [
          // papel off-white com luz quente de fim de tarde e a areia ao pé do cabeçalho
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.7, -1.1),
                radius: 1.4,
                colors: [Color(0x55E3CBA0), Color(0x14E3CBA0), Paleta.fundo],
                stops: [0, 0.5, 1],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 1,
            child: Opacity(opacity: 1 - aberto, child: const ColoredBox(color: Paleta.linha)),
          ),
          if (aberto > 0.05)
            Opacity(
              opacity: Curves.easeIn.transform(aberto),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    LayoutBuilder(
                      builder: (context, k) => Marca(largura: k.maxWidth.clamp(200.0, 360.0)),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Paleta.superficie,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Paleta.douradoSuave),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.delivery_dining_outlined, size: 16, color: Paleta.piscina),
                        SizedBox(width: 6),
                        Text('Entrega no seu apartamento',
                            style: TextStyle(color: Paleta.verde, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          // marca compacta quando recolhido
          Positioned(
            left: 56,
            right: 56,
            bottom: 0,
            height: kToolbarHeight,
            child: IgnorePointer(
              child: Opacity(
                opacity: (1 - aberto * 2).clamp(0.0, 1.0),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Marca(versao: VersaoMarca.compacta, altura: 40),
                ]),
              ),
            ),
          ),
        ]);
      }),
    );
  }
}

class _Ornamento extends StatelessWidget {
  const _Ornamento();

  @override
  Widget build(BuildContext context) {
    Widget linha() => Container(
          width: 48,
          height: 1,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Colors.transparent, Paleta.douradoSuave, Colors.transparent]),
          ),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      linha(),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: Marca(versao: VersaoMarca.simbolo, largura: 34),
      ),
      linha(),
    ]);
  }
}

class _TituloSecao extends StatelessWidget {
  const _TituloSecao(this.titulo, {this.quantidade, this.subtitulo});

  final String titulo;
  final int? quantidade;
  final String? subtitulo;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Flexible(child: Text(titulo, style: serifa(26))),
        if (quantidade != null) ...[
          const SizedBox(width: 10),
          Text('$quantidade ${quantidade == 1 ? 'item' : 'itens'}',
              style: const TextStyle(color: Paleta.textoSuave, fontSize: 13)),
        ],
      ]),
      const SizedBox(height: 6),
      Container(width: 36, height: 2, color: Paleta.douradoSuave),
      if (subtitulo != null) ...[
        const SizedBox(height: 8),
        Text(subtitulo!, style: const TextStyle(color: Paleta.textoSuave, fontSize: 13)),
      ],
    ]);
  }
}

// =============================================================================
// Busca e filtros (fixos no topo ao rolar)
// =============================================================================

class _BarraFiltros extends SliverPersistentHeaderDelegate {
  _BarraFiltros({
    required this.busca,
    required this.filtro,
    required this.ordem,
    required this.cardapio,
    required this.margem,
    required this.aoFiltrar,
    required this.aoOrdenar,
  });

  final TextEditingController busca;
  final _Filtro filtro;
  final _Ordem ordem;
  final Cardapio cardapio;
  final double margem;
  final ValueChanged<_Filtro> aoFiltrar;
  final ValueChanged<_Ordem> aoOrdenar;

  static const _altura = 118.0;

  @override
  double get minExtent => _altura;

  @override
  double get maxExtent => _altura;

  // Recriado a cada setState da página (busca, filtro, ordem): sempre redesenha.
  @override
  bool shouldRebuild(covariant _BarraFiltros antigo) => true;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    Widget chip(String rotulo, _Filtro f, {IconData? icone}) {
      final selecionado = switch ((filtro, f)) {
        (_Tudo(), _Tudo()) => true,
        (_Promocoes(), _Promocoes()) => true,
        (_Categoria(id: final a), _Categoria(id: final b)) => a == b,
        _ => false,
      };
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          avatar: icone == null
              ? null
              : Icon(icone, size: 16, color: selecionado ? Paleta.fundo : Paleta.promocao),
          label: Text(rotulo),
          selected: selecionado,
          labelStyle: TextStyle(
            color: selecionado ? Paleta.fundo : Paleta.texto,
            fontWeight: selecionado ? FontWeight.w700 : FontWeight.w500,
          ),
          onSelected: (_) => aoFiltrar(selecionado && f is! _Tudo ? const _Tudo() : f),
        ),
      );
    }

    return Container(
      color: Paleta.fundo.withValues(alpha: 0.97),
      child: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(margem, 8, margem, 8),
          child: Row(children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: TextField(
                  controller: busca,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Buscar no cardápio',
                    prefixIcon: const Icon(Icons.search, color: Paleta.textoSuave),
                    suffixIcon: busca.text.isEmpty
                        ? null
                        : IconButton(onPressed: busca.clear, icon: const Icon(Icons.close, size: 18)),
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Paleta.linha),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Paleta.linha),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Paleta.verde),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<_Ordem>(
              tooltip: 'Ordenar',
              initialValue: ordem,
              color: Paleta.superficieAlta,
              onSelected: aoOrdenar,
              itemBuilder: (_) => [
                for (final o in _Ordem.values)
                  PopupMenuItem(
                    value: o,
                    child: Row(children: [
                      Icon(o == ordem ? Icons.radio_button_checked : Icons.radio_button_off,
                          size: 18, color: Paleta.verde),
                      const SizedBox(width: 10),
                      Text(o.rotulo),
                    ]),
                  ),
              ],
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ordem == _Ordem.relevancia ? Paleta.superficieAlta : Paleta.verde,
                  border: Border.all(color: Paleta.linha),
                ),
                child: Icon(Icons.tune, color: ordem == _Ordem.relevancia ? Paleta.texto : Paleta.fundo),
              ),
            ),
          ]),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.fromLTRB(margem, 0, margem, 8),
            children: [
              chip('Tudo', const _Tudo()),
              if (cardapio.temPromocoes) chip('Promoções', const _Promocoes(), icone: Icons.local_offer),
              for (final cat in cardapio.categorias) chip(cat.nome, _Categoria(cat.id)),
            ],
          ),
        ),
        const Divider(height: 1),
      ]),
    );
  }
}

// =============================================================================
// Vitrine (destaques configurados no painel)
// =============================================================================

String _subtituloSecao(String tipo) => switch (tipo) {
      'SUGESTOES' => 'Escolhidos a dedo pela casa',
      'PROMOCOES' => 'Por tempo limitado',
      'MAIS_PEDIDOS' => 'Os favoritos dos nossos clientes',
      'MENOS_PEDIDOS' => 'Joias escondidas que valem a prova',
      'NOVIDADES' => 'Acabaram de chegar',
      _ => '',
    };

/// Primeira seção: carrossel grande, cartões com foto inteira.
class _VitrinePrincipal extends StatefulWidget {
  const _VitrinePrincipal({required this.secao, required this.margem, required this.maisPedidos, required this.aoTocar});

  final SecaoDestaque secao;
  final double margem;
  final Set<String> maisPedidos;
  final ValueChanged<ProdutoCardapio> aoTocar;

  @override
  State<_VitrinePrincipal> createState() => _VitrinePrincipalState();
}

class _VitrinePrincipalState extends State<_VitrinePrincipal> {
  late final _paginas = PageController(viewportFraction: 0.86);
  int _atual = 0;

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.secao;
    final largura = math.min(MediaQuery.sizeOf(context).width, 760.0);
    final altura = math.min(largura * 0.95, 380.0);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.margem),
          child: _TituloSecao(s.titulo, subtitulo: _subtituloSecao(s.tipo)),
        ),
        const SizedBox(height: 14),
        Center(
          child: SizedBox(
            width: largura,
            height: altura,
            child: PageView.builder(
              controller: _paginas,
              itemCount: s.produtos.length,
              onPageChanged: (i) => setState(() => _atual = i),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _CartaoDestaque(
                  produto: s.produtos[i],
                  grande: true,
                  posicao: s.tipo == 'MAIS_PEDIDOS' ? i + 1 : null,
                  maisPedido: widget.maisPedidos.contains(s.produtos[i].id),
                  aoTocar: () => widget.aoTocar(s.produtos[i]),
                ),
              ),
            ),
          ),
        ),
        if (s.produtos.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < s.produtos.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _atual ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _atual ? Paleta.verde : Paleta.linha,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ]),
          ),
      ]),
    );
  }
}

/// Demais seções: faixa horizontal de cartões médios.
class _VitrineHorizontal extends StatelessWidget {
  const _VitrineHorizontal({required this.secao, required this.margem, required this.maisPedidos, required this.aoTocar});

  final SecaoDestaque secao;
  final double margem;
  final Set<String> maisPedidos;
  final ValueChanged<ProdutoCardapio> aoTocar;

  @override
  Widget build(BuildContext context) {
    final s = secao;
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: margem),
          child: _TituloSecao(s.titulo, subtitulo: _subtituloSecao(s.tipo)),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 270,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: margem),
            itemCount: s.produtos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => SizedBox(
              width: 196,
              child: _CartaoDestaque(
                produto: s.produtos[i],
                grande: false,
                posicao: s.tipo == 'MAIS_PEDIDOS' ? i + 1 : null,
                maisPedido: maisPedidos.contains(s.produtos[i].id),
                aoTocar: () => aoTocar(s.produtos[i]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Cartão com a foto ocupando tudo e o texto sobre um degradê escuro.
class _CartaoDestaque extends StatelessWidget {
  const _CartaoDestaque({
    required this.produto,
    required this.grande,
    required this.aoTocar,
    this.posicao,
    this.maisPedido = false,
  });

  final ProdutoCardapio produto;
  final bool grande;
  final int? posicao;
  final bool maisPedido;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final p = produto;
    return Opacity(
      opacity: p.esgotado ? 0.5 : 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(grande ? 24 : 18),
        child: Material(
          color: Paleta.superficie,
          child: InkWell(
            onTap: p.esgotado ? null : aoTocar,
            child: Stack(fit: StackFit.expand, children: [
              _Foto(url: p.imagemUrl, tamanhoIcone: grande ? 64 : 40, escuro: true),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x330B2A1E), Color(0xEE0B2A1E)],
                    stops: [0.35, 0.55, 1],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Row(children: [
                  if (posicao != null) _Posicao(posicao!),
                  const Spacer(),
                  _Etiquetas(produto: p, maisPedido: maisPedido && posicao == null, compacto: !grande),
                ]),
              ),
              Positioned(
                left: grande ? 20 : 14,
                right: grande ? 20 : 14,
                bottom: grande ? 20 : 14,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.nome,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: serifa(grande ? 26 : 18, altura: 1.1, cor: Paleta.sobreFoto)),
                  if (grande && p.descricao != null && p.descricao!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(p.descricao!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Paleta.sobreFotoSuave, fontSize: 13, height: 1.35)),
                  ],
                  SizedBox(height: grande ? 12 : 8),
                  Row(children: [
                    Expanded(child: _Preco(produto: p, tamanho: grande ? 20 : 16, sobreFoto: true)),
                    if (!p.esgotado) _BotaoMais(tamanho: grande ? 40 : 32),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Posicao extends StatelessWidget {
  const _Posicao(this.numero);
  final int numero;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Paleta.fundo.withValues(alpha: 0.75),
        border: Border.all(color: Paleta.verde),
      ),
      child: Text('$numero', style: serifa(16, cor: Paleta.verde)),
    );
  }
}

// =============================================================================
// Linha de produto (lista por categoria e resultados)
// =============================================================================

class _LinhaProduto extends StatelessWidget {
  const _LinhaProduto({required this.produto, required this.carrinho, required this.maisPedido, required this.aoTocar});

  final ProdutoCardapio produto;
  final Carrinho carrinho;
  final bool maisPedido;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final p = produto;
    return Opacity(
      opacity: p.esgotado ? 0.45 : 1,
      child: InkWell(
        onTap: p.esgotado ? null : aoTocar,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Etiquetas(produto: p, maisPedido: maisPedido, compacto: true, alinharInicio: true),
                Text(p.nome, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.25)),
                if (p.descricao != null && p.descricao!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(p.descricao!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Paleta.textoSuave, fontSize: 13.5, height: 1.4)),
                ],
                const SizedBox(height: 10),
                _Preco(produto: p, tamanho: 17),
              ]),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 104,
              height: 104,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _Foto(url: p.imagemUrl, tamanhoIcone: 34),
                  ),
                ),
                if (!p.esgotado)
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: ListenableBuilder(
                      listenable: carrinho,
                      builder: (_, _) {
                        final qtd = carrinho.quantidadeDe(p.id);
                        return qtd == 0
                            ? const _BotaoMais(tamanho: 34)
                            : Container(
                                height: 34,
                                constraints: const BoxConstraints(minWidth: 34),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Paleta.verde,
                                  borderRadius: BorderRadius.circular(17),
                                  border: Border.all(color: Paleta.fundo, width: 3),
                                ),
                                child: Text('$qtd',
                                    style: const TextStyle(color: Paleta.fundo, fontWeight: FontWeight.w800)),
                              );
                      },
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// =============================================================================
// Carregando e cardápio vazio
// =============================================================================

/// Carregamento com mensagens conforme o tempo passa, para não parecer travado.
class _Carregando extends StatefulWidget {
  const _Carregando();

  @override
  State<_Carregando> createState() => _CarregandoState();
}

class _CarregandoState extends State<_Carregando> {
  static const _mensagens = [
    (Duration.zero, 'Carregando o cardápio…'),
    (Duration(seconds: 4), 'Quase lá… preparando o cardápio'),
    (Duration(seconds: 10), 'Sua conexão parece lenta. Ainda carregando…'),
  ];
  final _inicio = DateTime.now();
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final decorrido = DateTime.now().difference(_inicio);
    final mensagem = _mensagens.lastWhere((m) => decorrido >= m.$1).$2;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3.5)),
          const SizedBox(height: 20),
          const Marca(largura: 220),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(mensagem,
                key: ValueKey(mensagem),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Paleta.textoSuave, height: 1.5)),
          ),
        ]),
      ),
    );
  }
}

class _CardapioVazio extends StatelessWidget {
  const _CardapioVazio();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 140),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Paleta.douradoSuave)),
          child: const Icon(Icons.restaurant_menu, size: 38, color: Paleta.verde),
        ),
        const SizedBox(height: 20),
        Text('Cardápio em preparação', textAlign: TextAlign.center, style: serifa(24)),
        const SizedBox(height: 10),
        const Text(
          'Estamos organizando os itens do cardápio.\nVolte daqui a pouco para fazer seu pedido.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Paleta.textoSuave, height: 1.5),
        ),
        const SizedBox(height: 18),
        const _Ornamento(),
      ]),
    );
  }
}

// =============================================================================
// Peças pequenas
// =============================================================================

class _Foto extends StatelessWidget {
  const _Foto({required this.url, required this.tamanhoIcone, this.escuro = false});

  final String? url;
  final double tamanhoIcone;

  /// Sem foto: fundo verde da marca (cartões com texto claro) em vez do areia.
  final bool escuro;

  @override
  Widget build(BuildContext context) {
    final vazio = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: escuro ? const [Paleta.verdeMedio, Paleta.verde] : const [Paleta.superficieAlta, Paleta.areia],
        ),
      ),
      child: Center(
        child: escuro
            ? Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Marca(versao: VersaoMarca.simbolo, largura: tamanhoIcone * 2, cor: Paleta.douradoClaro),
              )
            : Icon(Icons.local_bar_outlined, size: tamanhoIcone, color: Paleta.verde.withValues(alpha: 0.5)),
      ),
    );
    if (url == null) return vazio;
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => vazio,
      frameBuilder: (_, child, frame, sincrono) => sincrono
          ? child
          : AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 300),
              child: frame == null ? vazio : child,
            ),
    );
  }
}

class _Preco extends StatelessWidget {
  const _Preco({required this.produto, required this.tamanho, this.sobreFoto = false});

  final ProdutoCardapio produto;
  final double tamanho;
  final bool sobreFoto;

  @override
  Widget build(BuildContext context) {
    final p = produto;
    if (p.esgotado) {
      return Text('Esgotado', style: TextStyle(color: Paleta.erro, fontWeight: FontWeight.w700, fontSize: tamanho - 3));
    }
    return Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      Text(formatarMoeda(p.preco),
          style: TextStyle(
            color: sobreFoto ? Paleta.douradoClaro : (p.emPromocao ? Paleta.promocao : Paleta.verde),
            fontWeight: FontWeight.w700,
            fontSize: tamanho,
          )),
      if (p.emPromocao)
        Text(formatarMoeda(p.precoOriginal),
            style: TextStyle(
              color: sobreFoto ? Paleta.sobreFotoSuave : Paleta.textoSuave,
              fontSize: tamanho - 4,
              decoration: TextDecoration.lineThrough,
              decorationColor: sobreFoto ? Paleta.sobreFotoSuave : Paleta.textoSuave,
            )),
    ]);
  }
}

class _Etiquetas extends StatelessWidget {
  const _Etiquetas({
    required this.produto,
    required this.maisPedido,
    this.compacto = false,
    this.alinharInicio = false,
  });

  final ProdutoCardapio produto;
  final bool maisPedido;
  final bool compacto;
  final bool alinharInicio;

  @override
  Widget build(BuildContext context) {
    final p = produto;
    final etiquetas = <Widget>[
      if (p.emPromocao) _Etiqueta('−${p.descontoPercentual}%', cor: Paleta.promocao, cheia: true),
      if (p.sugestao) _Etiqueta(compacto ? 'Sugestão' : 'Sugestão da casa', cor: Paleta.verde, icone: Icons.star),
      if (maisPedido) _Etiqueta('Mais pedido', cor: Paleta.dourado, icone: Icons.local_fire_department),
    ];
    if (etiquetas.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: alinharInicio ? 6 : 0),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        alignment: alinharInicio ? WrapAlignment.start : WrapAlignment.end,
        children: etiquetas,
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto, {required this.cor, this.icone, this.cheia = false});

  final String texto;
  final Color cor;
  final IconData? icone;
  final bool cheia;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cheia ? cor : Paleta.fundo.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: cheia ? null : Border.all(color: cor.withValues(alpha: 0.7)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icone != null) ...[Icon(icone, size: 12, color: cor), const SizedBox(width: 4)],
        Text(texto,
            style: TextStyle(
              color: cheia ? Paleta.fundo : cor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            )),
      ]),
    );
  }
}

class _BotaoMais extends StatelessWidget {
  const _BotaoMais({required this.tamanho});
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Paleta.verde,
        border: Border.all(color: Paleta.fundo, width: 3),
      ),
      child: Icon(Icons.add, size: tamanho * 0.55, color: Paleta.fundo),
    );
  }
}

class _BotaoCarrinho extends StatelessWidget {
  const _BotaoCarrinho({required this.carrinho, required this.aoTocar});

  final Carrinho carrinho;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(color: Color(0x40123F2D), blurRadius: 20, offset: Offset(0, 8))],
          ),
          child: FilledButton(
            onPressed: aoTocar,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: Row(children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Paleta.fundo),
                child: Text('${carrinho.quantidade}',
                    style: const TextStyle(color: Paleta.verde, fontSize: 13, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Ver meu pedido')),
              Text(formatarMoeda(carrinho.total)),
            ]),
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
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Paleta.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Paleta.douradoSuave),
      ),
      child: Row(children: [
        Icon(icone, color: Paleta.verde),
        const SizedBox(width: 12),
        Expanded(child: Text(texto, style: const TextStyle(height: 1.4))),
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
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: Paleta.verde,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: aoAbrir,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Icon(Icons.receipt_long, color: Paleta.fundo),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Pedido nº ${pedido.numero} · ${pedido.etapa.titulo}',
                    style: const TextStyle(color: Paleta.fundo, fontWeight: FontWeight.w700)),
              ),
              const Text('Acompanhar', style: TextStyle(color: Paleta.fundo)),
              const Icon(Icons.chevron_right, color: Paleta.fundo),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Rodape extends StatelessWidget {
  const _Rodape();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 48, 24, 140),
      child: Column(children: [
        _Ornamento(),
        SizedBox(height: 12),
        Text('Pagamento na entrega.\nBeba com moderação.',
            textAlign: TextAlign.center, style: TextStyle(color: Paleta.textoSuave, fontSize: 12, height: 1.6)),
      ]),
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (p.imagemUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(aspectRatio: 4 / 3, child: _Foto(url: p.imagemUrl, tamanhoIcone: 56)),
                ),
                const SizedBox(height: 18),
              ],
              _Etiquetas(produto: p, maisPedido: false, alinharInicio: true),
              Text(p.categoria.toUpperCase(), style: rotuloEspacado(tamanho: 10)),
              const SizedBox(height: 6),
              Text(p.nome, style: serifa(28, altura: 1.15)),
              if (p.descricao != null && p.descricao!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(p.descricao!, style: const TextStyle(color: Paleta.textoSuave, height: 1.5)),
              ],
              const SizedBox(height: 14),
              _Preco(produto: p, tamanho: 22),
              const SizedBox(height: 20),
              TextField(
                controller: _obs,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Alguma observação?',
                  hintText: 'Ex.: sem cebola, bem gelada, sem gelo',
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                _Quantidade(
                  valor: _quantidade,
                  aoMenos: _quantidade > 1 ? () => setState(() => _quantidade--) : null,
                  aoMais: _quantidade < 50 ? () => setState(() => _quantidade++) : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: FilledButton(
                    onPressed: widget.aberto
                        ? () {
                            widget.carrinho.adicionar(p, _quantidade, _obs.text);
                            Navigator.pop(context);
                          }
                        : null,
                    child: Text(widget.aberto ? 'Adicionar · ${formatarMoeda(p.preco * _quantidade)}' : 'Pedidos pausados'),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Quantidade extends StatelessWidget {
  const _Quantidade({required this.valor, this.aoMenos, this.aoMais, this.iconeMenos = Icons.remove});

  final int valor;
  final VoidCallback? aoMenos;
  final VoidCallback? aoMais;
  final IconData iconeMenos;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Paleta.linha),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(onPressed: aoMenos, icon: Icon(iconeMenos, size: 20), color: Paleta.verde),
        SizedBox(
          width: 28,
          child: Text('$valor', textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ),
        IconButton(onPressed: aoMais, icon: const Icon(Icons.add, size: 20), color: Paleta.verde),
      ]),
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
  final _bloco = TextEditingController();
  final _apartamento = TextEditingController();
  final _obs = TextEditingController();
  bool _enviando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    // Preenche com os dados do último pedido feito neste celular
    Memoria.cliente().then((c) {
      if (!mounted) return;
      if (c.nome != null && _nome.text.isEmpty) _nome.text = c.nome!;
      if (c.bloco != null && _bloco.text.isEmpty) _bloco.text = c.bloco!;
      if (c.apartamento != null && _apartamento.text.isEmpty) _apartamento.text = c.apartamento!;
    });
  }

  @override
  void dispose() {
    _nome.dispose();
    _bloco.dispose();
    _apartamento.dispose();
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
          nome: _nome.text.trim(),
          bloco: _bloco.text.trim(),
          apartamento: _apartamento.text.trim(),
          observacao: _obs.text);
      await Memoria.salvarCliente(
          nome: _nome.text.trim(), bloco: _bloco.text.trim(), apartamento: _apartamento.text.trim());
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
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Form(
                  key: _form,
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('Seu pedido', style: serifa(28)),
                    const SizedBox(height: 4),
                    Container(width: 36, height: 2, color: Paleta.verde),
                    const SizedBox(height: 16),
                    for (final i in c.itens)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(i.produto.nome, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                              if (i.observacao != null)
                                Text(i.observacao!,
                                    style: const TextStyle(
                                        color: Paleta.textoSuave, fontSize: 13, fontStyle: FontStyle.italic)),
                              const SizedBox(height: 2),
                              Text(formatarMoeda(i.total), style: const TextStyle(color: Paleta.verde)),
                            ]),
                          ),
                          _Quantidade(
                            valor: i.quantidade,
                            iconeMenos: i.quantidade == 1 ? Icons.delete_outline : Icons.remove,
                            aoMenos: () => c.alterar(i, -1),
                            aoMais: i.quantidade < 50 ? () => c.alterar(i, 1) : null,
                          ),
                        ]),
                      ),
                    const Divider(height: 20),
                    Row(children: [
                      const Expanded(child: Text('Total', style: TextStyle(fontSize: 17))),
                      Text(formatarMoeda(c.total), style: serifa(26, cor: Paleta.verde)),
                    ]),
                    const SizedBox(height: 4),
                    const Text('O pagamento é feito na entrega.',
                        style: TextStyle(color: Paleta.textoSuave, fontSize: 13)),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _nome,
                      maxLength: 80,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Seu nome', prefixIcon: Icon(Icons.person_outline)),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe seu nome' : null,
                    ),
                    const SizedBox(height: 4),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: TextFormField(
                          controller: _bloco,
                          maxLength: 20,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Bloco',
                            hintText: 'Ex.: B',
                            prefixIcon: Icon(Icons.apartment_outlined),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o bloco' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _apartamento,
                          maxLength: 20,
                          keyboardType: TextInputType.text,
                          decoration: const InputDecoration(
                            labelText: 'Apartamento',
                            hintText: 'Ex.: 101',
                            prefixIcon: Icon(Icons.door_front_door_outlined),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o apto.' : null,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _obs,
                      maxLength: 500,
                      decoration: const InputDecoration(
                          labelText: 'Observação geral (opcional)', prefixIcon: Icon(Icons.edit_note)),
                    ),
                    if (_erro != null) ...[
                      Text(_erro!, style: const TextStyle(color: Paleta.erro)),
                      const SizedBox(height: 10),
                    ],
                    FilledButton(
                      onPressed: _enviando ? null : _enviar,
                      child: _enviando
                          ? const SizedBox(
                              width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Paleta.fundo))
                          : Text('Enviar pedido · ${formatarMoeda(c.total)}'),
                    ),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
