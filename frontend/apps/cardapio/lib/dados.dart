import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _apiUrlInformada = String.fromEnvironment('API_URL');

/// Produção: o cardápio e a API saem pelo mesmo nginx (porta 80), então usa a origem da página.
/// Desenvolvimento: flutter run -d chrome --dart-define=API_URL=http://localhost:8080
final api = ApiClient(baseUrl: _apiUrlInformada.isNotEmpty ? _apiUrlInformada : Uri.base.origin);

// =============================================================================
// Modelos
// =============================================================================

class ProdutoCardapio {
  const ProdutoCardapio({
    required this.id,
    required this.nome,
    this.descricao,
    required this.preco,
    this.precoOriginal,
    this.imagemUrl,
    required this.esgotado,
    required this.sugestao,
    required this.categoriaId,
    required this.categoria,
  });

  final String id;
  final String nome;
  final String? descricao;

  /// Preço cobrado hoje (já com o desconto da promoção, se houver).
  final num preco;

  /// Preço normal, presente só durante a promoção.
  final num? precoOriginal;
  final String? imagemUrl;
  final bool esgotado;

  /// "Sugestão da casa".
  final bool sugestao;
  final String categoriaId;
  final String categoria;

  bool get emPromocao => precoOriginal != null && precoOriginal! > preco;

  /// Desconto arredondado em % (ex.: 20).
  int get descontoPercentual => emPromocao ? ((1 - preco / precoOriginal!) * 100).round() : 0;

  factory ProdutoCardapio.fromJson(Map<String, dynamic> j, String categoriaId, String categoria) => ProdutoCardapio(
        id: j['id'] as String,
        nome: j['nome'] as String,
        descricao: j['descricao'] as String?,
        preco: numDoJson(j['preco']) ?? 0,
        precoOriginal: numDoJson(j['precoOriginal']),
        imagemUrl: api.urlImagem(j['imagemUrl'] as String?),
        esgotado: j['esgotado'] as bool? ?? false,
        sugestao: j['destaque'] as bool? ?? false,
        categoriaId: categoriaId,
        categoria: categoria,
      );
}

class CategoriaCardapio {
  const CategoriaCardapio(this.id, this.nome, this.produtos);

  final String id;
  final String nome;
  final List<ProdutoCardapio> produtos;

  factory CategoriaCardapio.fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String;
    final nome = j['nome'] as String;
    return CategoriaCardapio(
      id,
      nome,
      (j['produtos'] as List).map((e) => ProdutoCardapio.fromJson(e as Map<String, dynamic>, id, nome)).toList(),
    );
  }
}

/// Seção de destaque da vitrine (configurada no painel): sugestões, promoções, mais pedidos…
class SecaoDestaque {
  const SecaoDestaque(this.tipo, this.titulo, this.produtos);

  final String tipo;
  final String titulo;
  final List<ProdutoCardapio> produtos;
}

class Cardapio {
  const Cardapio(this.nomeBar, this.aberto, this.categorias, this.destaques);

  final String nomeBar;
  final bool aberto;
  final List<CategoriaCardapio> categorias;
  final List<SecaoDestaque> destaques;

  Iterable<ProdutoCardapio> get produtos => categorias.expand((c) => c.produtos);

  /// Ids da seção "mais pedidos", para a etiqueta nos cartões.
  Set<String> get maisPedidos =>
      {for (final s in destaques.where((s) => s.tipo == 'MAIS_PEDIDOS')) ...s.produtos.map((p) => p.id)};

  bool get temPromocoes => produtos.any((p) => p.emPromocao);

  factory Cardapio.fromJson(Map<String, dynamic> j) {
    final categorias =
        (j['categorias'] as List).map((e) => CategoriaCardapio.fromJson(e as Map<String, dynamic>)).toList();
    final porId = {for (final p in categorias.expand((c) => c.produtos)) p.id: p};
    final destaques = <SecaoDestaque>[
      for (final s in ((j['destaques'] as List?) ?? const []).cast<Map<String, dynamic>>())
        SecaoDestaque(
          s['tipo'] as String,
          s['titulo'] as String,
          [for (final id in (s['produtos'] as List).cast<String>()) ?porId[id]],
        ),
    ];
    return Cardapio(
      j['nomeBar'] as String,
      j['aberto'] as bool,
      categorias,
      destaques.where((s) => s.produtos.isNotEmpty).toList(),
    );
  }
}

enum EtapaPedido {
  recebido('RECEBIDO', 'Pedido enviado', 'Aguardando o bar confirmar'),
  aceito('ACEITO', 'Pedido confirmado', 'Já vamos começar a preparar'),
  emPreparo('EM_PREPARO', 'Em preparo', 'Seu pedido está sendo preparado'),
  pronto('PRONTO', 'Pronto!', 'Saindo para entrega no seu apartamento'),
  entregue('ENTREGUE', 'Entregue', 'Bom apetite!'),
  cancelado('CANCELADO', 'Pedido cancelado', 'Fale com a gente pelo WhatsApp se tiver dúvidas');

  const EtapaPedido(this.api, this.titulo, this.descricao);
  final String api;
  final String titulo;
  final String descricao;

  static EtapaPedido fromApi(String v) => values.firstWhere((e) => e.api == v);
}

class ItemAcompanhamento {
  const ItemAcompanhamento(this.produtoNome, this.quantidade, this.total, this.observacao);

  final String produtoNome;
  final int quantidade;
  final num total;
  final String? observacao;
}

class Acompanhamento {
  const Acompanhamento({
    required this.id,
    required this.numero,
    required this.clienteNome,
    required this.local,
    this.observacao,
    required this.etapa,
    required this.pago,
    required this.total,
    required this.itens,
    this.criadoEm,
    this.motivoCancelamento,
  });

  final String id;
  final int numero;
  final String clienteNome;
  final String local;
  final String? observacao;
  final EtapaPedido etapa;
  final bool pago;
  final num total;
  final List<ItemAcompanhamento> itens;
  final DateTime? criadoEm;
  final String? motivoCancelamento;

  /// Nada mais vai mudar: não precisa continuar consultando.
  bool get finalizado => etapa == EtapaPedido.cancelado || (etapa == EtapaPedido.entregue && pago);

  factory Acompanhamento.fromJson(Map<String, dynamic> j) => Acompanhamento(
        id: j['id'] as String,
        numero: j['numero'] as int,
        clienteNome: j['clienteNome'] as String,
        local: j['local'] as String,
        observacao: j['observacao'] as String?,
        etapa: EtapaPedido.fromApi(j['statusPreparo'] as String),
        pago: j['statusFinanceiro'] == 'PAGO',
        total: numDoJson(j['total']) ?? 0,
        itens: [
          for (final i in (j['itens'] as List).cast<Map<String, dynamic>>())
            ItemAcompanhamento(i['produtoNome'] as String, i['quantidade'] as int, numDoJson(i['total']) ?? 0,
                i['observacao'] as String?),
        ],
        criadoEm: dataDoJson(j['criadoEm']),
        motivoCancelamento: j['motivoCancelamento'] as String?,
      );
}

// =============================================================================
// Carrinho
// =============================================================================

class ItemCarrinho {
  ItemCarrinho(this.produto, this.quantidade, this.observacao);

  final ProdutoCardapio produto;
  int quantidade;
  String? observacao;

  num get total => produto.preco * quantidade;
}

class Carrinho extends ChangeNotifier {
  final itens = <ItemCarrinho>[];

  /// Chave de idempotência do pedido: reenviar (rede instável, toque duplo) não duplica o pedido.
  String chave = gerarUuid();

  int get quantidade => itens.fold(0, (s, i) => s + i.quantidade);
  num get total => itens.fold<num>(0, (s, i) => s + i.total);
  bool get vazio => itens.isEmpty;

  int quantidadeDe(String produtoId) =>
      itens.where((i) => i.produto.id == produtoId).fold(0, (s, i) => s + i.quantidade);

  void adicionar(ProdutoCardapio p, int quantidade, String? observacao) {
    final obs = (observacao == null || observacao.trim().isEmpty) ? null : observacao.trim();
    final existente = itens.where((i) => i.produto.id == p.id && i.observacao == obs).firstOrNull;
    if (existente != null) {
      existente.quantidade = (existente.quantidade + quantidade).clamp(1, 50);
    } else if (itens.length < 30) {
      itens.add(ItemCarrinho(p, quantidade.clamp(1, 50), obs));
    }
    notifyListeners();
  }

  void alterar(ItemCarrinho item, int delta) {
    item.quantidade += delta;
    if (item.quantidade <= 0) itens.remove(item);
    if (item.quantidade > 50) item.quantidade = 50;
    notifyListeners();
  }

  void limpar() {
    itens.clear();
    chave = gerarUuid();
    notifyListeners();
  }
}

// =============================================================================
// API e memória local
// =============================================================================

Future<Cardapio> buscarCardapio() async =>
    Cardapio.fromJson(await api.get('/api/public/cardapio') as Map<String, dynamic>);

Future<Acompanhamento> buscarPedido(String id) async =>
    Acompanhamento.fromJson(await api.get('/api/public/pedidos/$id') as Map<String, dynamic>);

Future<Acompanhamento> enviarPedido(Carrinho c,
    {required String nome, required String bloco, required String apartamento, String? observacao}) async {
  final corpo = {
    'chaveIdempotencia': c.chave,
    'clienteNome': nome,
    'bloco': bloco,
    'apartamento': apartamento,
    if (observacao != null && observacao.trim().isNotEmpty) 'observacao': observacao.trim(),
    'itens': [
      for (final i in c.itens)
        {'produtoId': i.produto.id, 'quantidade': i.quantidade, 'observacao': ?i.observacao},
    ],
  };
  return Acompanhamento.fromJson(await api.post('/api/public/pedidos', corpo: corpo) as Map<String, dynamic>);
}

/// Lembra o nome do cliente e os pedidos feitos neste celular (para acompanhar depois).
abstract final class Memoria {
  static final _prefs = SharedPreferencesAsync();

  /// Nome, bloco e apartamento do último pedido feito neste celular.
  static Future<({String? nome, String? bloco, String? apartamento})> cliente() async {
    try {
      return (
        nome: await _prefs.getString('cardapio.nome'),
        bloco: await _prefs.getString('cardapio.bloco'),
        apartamento: await _prefs.getString('cardapio.apartamento'),
      );
    } catch (_) {
      return (nome: null, bloco: null, apartamento: null);
    }
  }

  static Future<void> salvarCliente({required String nome, required String bloco, required String apartamento}) async {
    try {
      await _prefs.setString('cardapio.nome', nome);
      await _prefs.setString('cardapio.bloco', bloco);
      await _prefs.setString('cardapio.apartamento', apartamento);
    } catch (e) {
      debugPrint('Não foi possível salvar os dados do cliente: $e');
    }
  }

  static Future<List<String>> pedidos() async {
    try {
      return await _prefs.getStringList('cardapio.pedidos') ?? const [];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> lembrarPedido(String id) async {
    final atuais = [id, ...(await pedidos()).where((p) => p != id)].take(5).toList();
    try {
      await _prefs.setStringList('cardapio.pedidos', atuais);
    } catch (e) {
      debugPrint('Não foi possível lembrar o pedido: $e');
    }
  }
}
