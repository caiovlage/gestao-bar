package br.com.bar.gestao.pedido.application;

import br.com.bar.gestao.configuracao.application.ConfiguracaoService;
import br.com.bar.gestao.pedido.api.dto.PedidoDto;
import br.com.bar.gestao.pedido.api.dto.VitrineDto;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Cardápio público: produtos ativos, vendáveis, com preço, marcados "vende no cardápio" e de
 * categoria visível no cardápio. Nada de custo, estoque exato ou dados internos é exposto.
 * A vitrine (seções de destaque) segue a configuração do painel.
 */
@Service
@Transactional(readOnly = true)
public class CardapioService {

    private static final int DIAS_VENDAS = 30;

    private final JdbcClient jdbc;
    private final ConfiguracaoService configuracao;
    private final VitrineService vitrine;
    private final ZoneId fuso;

    public CardapioService(JdbcClient jdbc, ConfiguracaoService configuracao, VitrineService vitrine,
                           @Value("${app.fuso-horario:America/Sao_Paulo}") String fuso) {
        this.jdbc = jdbc;
        this.configuracao = configuracao;
        this.vitrine = vitrine;
        this.fuso = ZoneId.of(fuso);
    }

    /** Produto do cardápio com os dados necessários para validar um pedido. {@code preco} = preço de hoje. */
    record ItemDisponivel(UUID id, String nome, String descricao, BigDecimal preco, BigDecimal precoOriginal,
                          String imagemUrl, UUID categoriaId, String categoria, boolean esgotado, boolean destaque,
                          Instant criadoEm) {

        /** Desconto da promoção em % (0 sem promoção), para ordenar as promoções. */
        BigDecimal desconto() {
            if (precoOriginal == null || precoOriginal.signum() <= 0) return BigDecimal.ZERO;
            return BigDecimal.ONE.subtract(preco.divide(precoOriginal, 4, RoundingMode.HALF_UP));
        }
    }

    private static final String CONSULTA = """
            SELECT p.id, p.nome, p.descricao, p.preco_venda, p.preco_promocional, p.imagem_url, p.destaque_cardapio,
                   p.criado_em,
                   (p.preco_promocional IS NOT NULL AND p.preco_promocional < p.preco_venda
                    AND (p.promocao_ate IS NULL OR p.promocao_ate >= :hoje)) AS em_promocao,
                   c.id AS categoria_id, c.nome AS categoria,
                   (p.controla_estoque AND coalesce(e.quantidade - e.quantidade_reservada, 0) <= 0) AS sem_saldo
            FROM produto p
            JOIN categoria c ON c.id = p.categoria_id
            LEFT JOIN estoque e ON e.produto_id = p.id
            WHERE p.ativo AND p.vende_no_cardapio AND p.tipo <> 'INGREDIENTE' AND p.preco_venda IS NOT NULL
              AND c.ativo AND c.exibir_cardapio
            """;

    public PedidoDto.Cardapio cardapio() {
        List<ItemDisponivel> itens = consultar(CONSULTA + " ORDER BY c.ordem, lower(c.nome), lower(p.nome)", Map.of());
        Map<UUID, PedidoDto.CategoriaCardapio> categorias = new LinkedHashMap<>();
        for (ItemDisponivel i : itens) {
            categorias.computeIfAbsent(i.categoriaId(),
                            id -> new PedidoDto.CategoriaCardapio(id, i.categoria(), new ArrayList<>()))
                    .produtos()
                    .add(new PedidoDto.ProdutoCardapio(i.id(), i.nome(), i.descricao(), i.preco(), i.precoOriginal(),
                            i.imagemUrl(), i.esgotado(), i.destaque()));
        }
        String nome = configuracao.valor(ConfiguracaoService.NOME_BAR);
        return new PedidoDto.Cardapio(nome == null ? "Cardápio" : nome, aberto(), List.copyOf(categorias.values()),
                destaques(itens));
    }

    public boolean aberto() {
        return configuracao.ativo(ConfiguracaoService.CARDAPIO_ABERTO);
    }

    /** Somente os produtos pedidos que estão no cardápio agora (os ausentes não podem ser pedidos). */
    Map<UUID, ItemDisponivel> disponiveis(Collection<UUID> ids) {
        if (ids.isEmpty()) return Map.of();
        return consultar(CONSULTA + " AND p.id IN (:ids)", Map.of("ids", ids)).stream()
                .collect(Collectors.toMap(ItemDisponivel::id, Function.identity()));
    }

    // ---------------------------------------------------------------- vitrine

    private List<PedidoDto.SecaoDestaque> destaques(List<ItemDisponivel> itens) {
        // Esgotados não vão para a vitrine: destaque é para o que o cliente pode pedir agora.
        List<ItemDisponivel> pedidos = itens.stream().filter(i -> !i.esgotado()).toList();
        Map<UUID, BigDecimal> vendidos = null;
        List<PedidoDto.SecaoDestaque> secoes = new ArrayList<>();
        for (VitrineDto.Secao s : vitrine.listar()) {
            if (!s.ativa()) continue;
            if (vendidos == null && (s.tipo() == VitrineDto.TipoSecao.MAIS_PEDIDOS
                    || s.tipo() == VitrineDto.TipoSecao.MENOS_PEDIDOS)) {
                vendidos = vendidosNoPeriodo();
            }
            Map<UUID, BigDecimal> v = vendidos;
            List<UUID> ids = (switch (s.tipo()) {
                case SUGESTOES -> pedidos.stream().filter(ItemDisponivel::destaque);
                case PROMOCOES -> pedidos.stream().filter(i -> i.precoOriginal() != null)
                        .sorted(Comparator.comparing(ItemDisponivel::desconto).reversed());
                case NOVIDADES -> pedidos.stream()
                        .sorted(Comparator.comparing(ItemDisponivel::criadoEm, Comparator.reverseOrder()));
                case MAIS_PEDIDOS -> maisPedidos(pedidos, v);
                case MENOS_PEDIDOS -> pedidos.stream()
                        .sorted(Comparator.comparing((ItemDisponivel i) -> v.getOrDefault(i.id(), BigDecimal.ZERO))
                                .thenComparing(i -> i.nome().toLowerCase()));
            }).limit(s.quantidade()).map(ItemDisponivel::id).toList();
            if (!ids.isEmpty()) {
                secoes.add(new PedidoDto.SecaoDestaque(s.tipo(), s.titulo(), ids));
            }
        }
        return secoes;
    }

    /**
     * Mais vendidos primeiro. Com os dados de demonstração ligados e poucas vendas reais, completa
     * com outros produtos do cardápio (com foto primeiro), para a seção aparecer nas apresentações.
     */
    private java.util.stream.Stream<ItemDisponivel> maisPedidos(List<ItemDisponivel> pedidos, Map<UUID, BigDecimal> vendidos) {
        List<ItemDisponivel> comVenda = pedidos.stream().filter(i -> vendidos.containsKey(i.id()))
                .sorted(Comparator.comparing((ItemDisponivel i) -> vendidos.get(i.id())).reversed())
                .toList();
        if (comVenda.size() >= 3 || !configuracao.ativo(ConfiguracaoService.DADOS_DEMONSTRACAO)) {
            return comVenda.stream();
        }
        List<ItemDisponivel> resto = pedidos.stream().filter(i -> !vendidos.containsKey(i.id()))
                .sorted(Comparator.comparing((ItemDisponivel i) -> i.imagemUrl() == null)
                        .thenComparing(i -> i.id().toString()))
                .toList();
        List<ItemDisponivel> todos = new ArrayList<>(comVenda);
        todos.addAll(resto);
        return todos.stream();
    }

    /** Quantidade vendida por produto nos últimos 30 dias (vendas concluídas, inclusive as de pedidos). */
    private Map<UUID, BigDecimal> vendidosNoPeriodo() {
        Map<UUID, BigDecimal> mapa = new HashMap<>();
        jdbc.sql("""
                        SELECT i.produto_id, sum(i.quantidade) AS quantidade
                        FROM venda_item i
                        JOIN venda v ON v.id = i.venda_id
                        WHERE v.status = 'CONCLUIDA' AND v.data_hora >= :desde
                        GROUP BY i.produto_id
                        """)
                .param("desde", LocalDate.now(fuso).minusDays(DIAS_VENDAS).atStartOfDay(fuso).toOffsetDateTime())
                .query(rs -> {
                    mapa.put(rs.getObject("produto_id", UUID.class), rs.getBigDecimal("quantidade"));
                });
        return mapa;
    }

    private List<ItemDisponivel> consultar(String sql, Map<String, ?> params) {
        boolean permitirNegativo = configuracao.ativo(ConfiguracaoService.PERMITIR_ESTOQUE_NEGATIVO);
        return jdbc.sql(sql).params(params).param("hoje", LocalDate.now(fuso))
                .query((rs, n) -> {
                    boolean promocao = rs.getBoolean("em_promocao");
                    return new ItemDisponivel(rs.getObject("id", UUID.class), rs.getString("nome"),
                            rs.getString("descricao"),
                            promocao ? rs.getBigDecimal("preco_promocional") : rs.getBigDecimal("preco_venda"),
                            promocao ? rs.getBigDecimal("preco_venda") : null,
                            rs.getString("imagem_url"), rs.getObject("categoria_id", UUID.class),
                            rs.getString("categoria"), !permitirNegativo && rs.getBoolean("sem_saldo"),
                            rs.getBoolean("destaque_cardapio"),
                            rs.getObject("criado_em", java.time.OffsetDateTime.class).toInstant());
                })
                .list();
    }
}
