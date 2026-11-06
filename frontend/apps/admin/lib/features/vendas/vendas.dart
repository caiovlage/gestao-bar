import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

// =============================================================================
// Modelos
// =============================================================================

enum FormaPagamento {
  dinheiro('DINHEIRO', 'Dinheiro', Icons.payments_outlined),
  pix('PIX', 'PIX', Icons.qr_code_2),
  cartaoDebito('CARTAO_DEBITO', 'Débito', Icons.credit_card),
  cartaoCredito('CARTAO_CREDITO', 'Crédito', Icons.credit_score),
  outros('OUTROS', 'Outros', Icons.more_horiz);

  const FormaPagamento(this.api, this.rotulo, this.icone);
  final String api;
  final String rotulo;
  final IconData icone;

  static FormaPagamento fromApi(String v) => values.firstWhere((f) => f.api == v);
}

/// Produto à venda no PDV.
class ItemCatalogo {
  const ItemCatalogo({
    required this.produtoId,
    required this.nome,
    required this.precoVenda,
    this.categoriaId,
    this.categoria,
    this.imagemUrl,
    this.codigoInterno,
    required this.controlaEstoque,
    this.disponivel,
    required this.unidadeSigla,
    this.precoNormal,
  });

  final String produtoId;
  final String nome;
  final num precoVenda;
  final String? categoriaId;
  final String? categoria;
  final String? imagemUrl;
  final String? codigoInterno;
  final bool controlaEstoque;

  /// Saldo disponível (nulo quando o produto não controla estoque).
  final num? disponivel;
  final String unidadeSigla;

  /// Preço sem desconto: preenchido só durante a promoção ([precoVenda] já é o promocional).
  final num? precoNormal;

  bool get esgotado => controlaEstoque && (disponivel ?? 0) <= 0;

  factory ItemCatalogo.fromJson(Map<String, dynamic> j) => ItemCatalogo(
        produtoId: j['produtoId'] as String,
        nome: j['nome'] as String,
        precoVenda: numDoJson(j['precoVenda']) ?? 0,
        categoriaId: j['categoriaId'] as String?,
        categoria: j['categoria'] as String?,
        imagemUrl: j['imagemUrl'] as String?,
        codigoInterno: j['codigoInterno'] as String?,
        controlaEstoque: j['controlaEstoque'] as bool,
        disponivel: numDoJson(j['disponivel']),
        unidadeSigla: j['unidadeSigla'] as String,
        precoNormal: numDoJson(j['precoNormal']),
      );
}

class ItemVenda {
  const ItemVenda(this.produtoNome, this.quantidade, this.precoUnitario, this.total, this.custoTotal);

  final String produtoNome;
  final num quantidade;
  final num precoUnitario;
  final num total;
  final num custoTotal;

  factory ItemVenda.fromJson(Map<String, dynamic> j) => ItemVenda(
        j['produtoNome'] as String,
        numDoJson(j['quantidade']) ?? 0,
        numDoJson(j['precoUnitario']) ?? 0,
        numDoJson(j['total']) ?? 0,
        numDoJson(j['custoTotal']) ?? 0,
      );
}

class Venda {
  const Venda({
    required this.id,
    required this.numero,
    this.dataHora,
    required this.itens,
    required this.subtotal,
    required this.desconto,
    required this.total,
    required this.custoTotal,
    required this.lucroBruto,
    this.margemPercentual,
    required this.formaPagamento,
    this.valorRecebido,
    this.troco,
    this.observacao,
    required this.cancelada,
    this.motivoCancelamento,
    this.canceladaEm,
  });

  final String id;
  final int numero;
  final DateTime? dataHora;
  final List<ItemVenda> itens;
  final num subtotal;
  final num desconto;
  final num total;
  final num custoTotal;
  final num lucroBruto;
  final num? margemPercentual;
  final FormaPagamento formaPagamento;
  final num? valorRecebido;
  final num? troco;
  final String? observacao;
  final bool cancelada;
  final String? motivoCancelamento;
  final DateTime? canceladaEm;

  factory Venda.fromJson(Map<String, dynamic> j) => Venda(
        id: j['id'] as String,
        numero: (j['numero'] as num).toInt(),
        dataHora: dataDoJson(j['dataHora']),
        itens: (j['itens'] as List).map((e) => ItemVenda.fromJson(e as Map<String, dynamic>)).toList(),
        subtotal: numDoJson(j['subtotal']) ?? 0,
        desconto: numDoJson(j['desconto']) ?? 0,
        total: numDoJson(j['total']) ?? 0,
        custoTotal: numDoJson(j['custoTotal']) ?? 0,
        lucroBruto: numDoJson(j['lucroBruto']) ?? 0,
        margemPercentual: numDoJson(j['margemPercentual']),
        formaPagamento: FormaPagamento.fromApi(j['formaPagamento'] as String),
        valorRecebido: numDoJson(j['valorRecebido']),
        troco: numDoJson(j['troco']),
        observacao: j['observacao'] as String?,
        cancelada: j['status'] == 'CANCELADA',
        motivoCancelamento: j['motivoCancelamento'] as String?,
        canceladaEm: dataDoJson(j['canceladaEm']),
      );
}

class VendaResumo {
  const VendaResumo({
    required this.id,
    required this.numero,
    this.dataHora,
    required this.total,
    required this.lucroBruto,
    required this.formaPagamento,
    required this.cancelada,
    required this.quantidadeItens,
    this.itens,
  });

  final String id;
  final int numero;
  final DateTime? dataHora;
  final num total;
  final num lucroBruto;
  final FormaPagamento formaPagamento;
  final bool cancelada;
  final int quantidadeItens;
  final String? itens;

  factory VendaResumo.fromJson(Map<String, dynamic> j) => VendaResumo(
        id: j['id'] as String,
        numero: (j['numero'] as num).toInt(),
        dataHora: dataDoJson(j['dataHora']),
        total: numDoJson(j['total']) ?? 0,
        lucroBruto: numDoJson(j['lucroBruto']) ?? 0,
        formaPagamento: FormaPagamento.fromApi(j['formaPagamento'] as String),
        cancelada: j['status'] == 'CANCELADA',
        quantidadeItens: j['quantidadeItens'] as int? ?? 0,
        itens: j['itens'] as String?,
      );
}

/// Comprovante interno em texto (não é documento fiscal).
String comprovante(Venda v) {
  const largura = 40;
  String linha(String esq, String dir) {
    final espacos = largura - esq.length - dir.length;
    return espacos > 0 ? '$esq${' ' * espacos}$dir' : '$esq $dir';
  }

  final b = StringBuffer()
    ..writeln('COMPROVANTE INTERNO'.padLeft(30))
    ..writeln('não é documento fiscal'.padLeft(31))
    ..writeln('-' * largura)
    ..writeln(linha('Venda nº ${v.numero}', formatarDataHora(v.dataHora)))
    ..writeln('-' * largura);
  for (final i in v.itens) {
    b
      ..writeln(i.produtoNome.length > largura ? i.produtoNome.substring(0, largura) : i.produtoNome)
      ..writeln(linha('  ${formatarQuantidade(i.quantidade)} x ${formatarMoeda(i.precoUnitario)}', formatarMoeda(i.total)));
  }
  b
    ..writeln('-' * largura)
    ..writeln(linha('Subtotal', formatarMoeda(v.subtotal)));
  if (v.desconto > 0) b.writeln(linha('Desconto', '-${formatarMoeda(v.desconto)}'));
  b.writeln(linha('TOTAL', formatarMoeda(v.total)));
  b.writeln(linha('Pagamento', v.formaPagamento.rotulo));
  if (v.valorRecebido != null) b.writeln(linha('Recebido', formatarMoeda(v.valorRecebido)));
  if (v.troco != null && v.troco! > 0) b.writeln(linha('Troco', formatarMoeda(v.troco)));
  if (v.cancelada) {
    b
      ..writeln('-' * largura)
      ..writeln('*** VENDA CANCELADA ***')
      ..writeln(v.motivoCancelamento ?? '');
  }
  return b.toString();
}

// =============================================================================
// Repositório
// =============================================================================

class VendasRepository {
  VendasRepository(this._api);
  final ApiClient _api;

  static const _base = '/api/admin/vendas';

  String? urlImagem(String? caminho) => _api.urlImagem(caminho);

  Future<List<ItemCatalogo>> catalogo() async {
    final dados = await _api.get('$_base/catalogo') as List;
    return dados.map((e) => ItemCatalogo.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Venda> registrar(Carrinho c) async => Venda.fromJson(await _api.post(_base, corpo: {
        'chaveIdempotencia': c.chave,
        'itens': [
          for (final i in c.itens) {'produtoId': i.produto.produtoId, 'quantidade': i.quantidade},
        ],
        'desconto': c.descontoPercentual ? null : c.descontoInformado,
        'descontoPercentual': c.descontoPercentual ? c.descontoInformado : null,
        'formaPagamento': c.forma.api,
        'valorRecebido': c.forma == FormaPagamento.dinheiro ? c.valorRecebido : null,
      }) as Map<String, dynamic>);

  Future<PageResponse<VendaResumo>> pesquisar(FiltroVendas f) async {
    final dados = await _api.get(_base, query: {
      'inicio': f.periodo == null ? null : dataParaApi(f.periodo!.start),
      'fim': f.periodo == null ? null : dataParaApi(f.periodo!.end),
      'status': f.status,
      'caixaId': f.caixaId,
      'page': f.pagina,
      'size': 50,
    });
    return PageResponse.fromJson(dados as Map<String, dynamic>, VendaResumo.fromJson);
  }

  Future<Venda> buscar(String id) async => Venda.fromJson(await _api.get('$_base/$id') as Map<String, dynamic>);

  Future<Venda> cancelar(String id, String motivo) async =>
      Venda.fromJson(await _api.post('$_base/$id/cancelar', corpo: {'motivo': motivo}) as Map<String, dynamic>);
}

final vendasRepositoryProvider = Provider((ref) => VendasRepository(ref.watch(apiClientProvider)));

final catalogoPdvProvider = FutureProvider.autoDispose<List<ItemCatalogo>>(
  (ref) => ref.watch(vendasRepositoryProvider).catalogo(),
);

// =============================================================================
// Carrinho do PDV
// =============================================================================

class ItemCarrinho {
  const ItemCarrinho(this.produto, this.quantidade);

  final ItemCatalogo produto;
  final int quantidade;

  num get total => produto.precoVenda * quantidade;
}

class Carrinho {
  const Carrinho({
    required this.chave,
    this.itens = const [],
    this.descontoInformado,
    this.descontoPercentual = false,
    this.forma = FormaPagamento.pix,
    this.valorRecebido,
  });

  /// Chave de idempotência: a mesma venda reenviada não é registrada duas vezes.
  final String chave;
  final List<ItemCarrinho> itens;
  final num? descontoInformado;
  final bool descontoPercentual;
  final FormaPagamento forma;
  final num? valorRecebido;

  bool get vazio => itens.isEmpty;
  int get quantidadeItens => itens.fold(0, (s, i) => s + i.quantidade);

  // Valores apenas para exibição; o servidor recalcula e é a referência.
  num get subtotal => itens.fold<num>(0, (s, i) => s + i.total);
  num get desconto {
    final d = descontoInformado ?? 0;
    final valor = descontoPercentual ? subtotal * d / 100 : d;
    return (valor * 100).round() / 100;
  }

  num get total => subtotal - desconto;
  num? get troco => forma == FormaPagamento.dinheiro && valorRecebido != null ? valorRecebido! - total : null;

  Carrinho copiar({
    List<ItemCarrinho>? itens,
    num? Function()? descontoInformado,
    bool? descontoPercentual,
    FormaPagamento? forma,
    num? Function()? valorRecebido,
  }) =>
      Carrinho(
        chave: chave,
        itens: itens ?? this.itens,
        descontoInformado: descontoInformado == null ? this.descontoInformado : descontoInformado(),
        descontoPercentual: descontoPercentual ?? this.descontoPercentual,
        forma: forma ?? this.forma,
        valorRecebido: valorRecebido == null ? this.valorRecebido : valorRecebido(),
      );
}

class CarrinhoController extends Notifier<Carrinho> {
  @override
  Carrinho build() => Carrinho(chave: gerarUuid());

  void adicionar(ItemCatalogo produto) {
    final itens = [...state.itens];
    final i = itens.indexWhere((x) => x.produto.produtoId == produto.produtoId);
    if (i >= 0) {
      itens[i] = ItemCarrinho(produto, itens[i].quantidade + 1);
    } else {
      itens.add(ItemCarrinho(produto, 1));
    }
    state = state.copiar(itens: itens);
  }

  void alterarQuantidade(String produtoId, int delta) {
    final itens = [
      for (final x in state.itens)
        if (x.produto.produtoId != produtoId) x else if (x.quantidade + delta > 0) ItemCarrinho(x.produto, x.quantidade + delta),
    ];
    state = state.copiar(itens: itens);
  }

  void remover(String produtoId) =>
      state = state.copiar(itens: state.itens.where((x) => x.produto.produtoId != produtoId).toList());

  void desconto(num? valor, {required bool percentual}) =>
      state = state.copiar(descontoInformado: () => valor, descontoPercentual: percentual);

  void forma(FormaPagamento forma) => state = state.copiar(forma: forma);

  void valorRecebido(num? valor) => state = state.copiar(valorRecebido: () => valor);

  /// Nova venda: carrinho vazio e nova chave de idempotência.
  void limpar() => state = Carrinho(chave: gerarUuid());
}

final carrinhoProvider = NotifierProvider<CarrinhoController, Carrinho>(CarrinhoController.new);

// =============================================================================
// Histórico
// =============================================================================

class FiltroVendas {
  const FiltroVendas({this.periodo, this.status, this.caixaId, this.pagina = 0});

  final DateTimeRange? periodo;

  /// 'CONCLUIDA', 'CANCELADA' ou null (todas).
  final String? status;
  final String? caixaId;
  final int pagina;
}

class FiltroVendasController extends Notifier<FiltroVendas> {
  @override
  FiltroVendas build() {
    final hoje = DateTime.now();
    return FiltroVendas(periodo: DateTimeRange(start: hoje, end: hoje));
  }

  void periodo(DateTimeRange? p) => state = FiltroVendas(periodo: p, status: state.status, caixaId: state.caixaId);
  void status(String? s) => state = FiltroVendas(periodo: state.periodo, status: s, caixaId: state.caixaId);
  void caixa(String? id) => state = FiltroVendas(periodo: id == null ? state.periodo : null, status: state.status, caixaId: id);
  void pagina(int p) =>
      state = FiltroVendas(periodo: state.periodo, status: state.status, caixaId: state.caixaId, pagina: p);
}

final filtroVendasProvider = NotifierProvider<FiltroVendasController, FiltroVendas>(FiltroVendasController.new);

final vendasProvider = FutureProvider.autoDispose<PageResponse<VendaResumo>>(
  (ref) => ref.watch(vendasRepositoryProvider).pesquisar(ref.watch(filtroVendasProvider)),
);
