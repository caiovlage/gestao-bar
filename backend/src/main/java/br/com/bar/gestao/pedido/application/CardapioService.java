package br.com.bar.gestao.pedido.application;

import br.com.bar.gestao.configuracao.application.ConfiguracaoService;
import br.com.bar.gestao.pedido.api.dto.PedidoDto;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Cardápio público: produtos ativos, vendáveis, com preço, marcados "vende no cardápio" e de
 * categoria visível no cardápio. Nada de custo, estoque exato ou dados internos é exposto.
 */
@Service
@Transactional(readOnly = true)
public class CardapioService {

    private final JdbcClient jdbc;
    private final ConfiguracaoService configuracao;

    public CardapioService(JdbcClient jdbc, ConfiguracaoService configuracao) {
        this.jdbc = jdbc;
        this.configuracao = configuracao;
    }

    /** Produto do cardápio com os dados necessários para validar um pedido. */
    record ItemDisponivel(UUID id, String nome, String descricao, BigDecimal preco, String imagemUrl, UUID categoriaId,
                          String categoria, boolean esgotado) {
    }

    private static final String CONSULTA = """
            SELECT p.id, p.nome, p.descricao, p.preco_venda, p.imagem_url, c.id AS categoria_id, c.nome AS categoria,
                   (p.controla_estoque AND coalesce(e.quantidade - e.quantidade_reservada, 0) <= 0) AS sem_saldo
            FROM produto p
            JOIN categoria c ON c.id = p.categoria_id
            LEFT JOIN estoque e ON e.produto_id = p.id
            WHERE p.ativo AND p.vende_no_cardapio AND p.tipo <> 'INGREDIENTE' AND p.preco_venda IS NOT NULL
              AND c.ativo AND c.exibir_cardapio
            """;

    public PedidoDto.Cardapio cardapio() {
        Map<UUID, PedidoDto.CategoriaCardapio> categorias = new LinkedHashMap<>();
        for (ItemDisponivel i : consultar(CONSULTA + " ORDER BY c.ordem, lower(c.nome), lower(p.nome)", Map.of())) {
            categorias.computeIfAbsent(i.categoriaId(),
                            id -> new PedidoDto.CategoriaCardapio(id, i.categoria(), new ArrayList<>()))
                    .produtos()
                    .add(new PedidoDto.ProdutoCardapio(i.id(), i.nome(), i.descricao(), i.preco(), i.imagemUrl(),
                            i.esgotado()));
        }
        String nome = configuracao.valor(ConfiguracaoService.NOME_BAR);
        return new PedidoDto.Cardapio(nome == null ? "Cardápio" : nome, aberto(), List.copyOf(categorias.values()));
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

    private List<ItemDisponivel> consultar(String sql, Map<String, ?> params) {
        boolean permitirNegativo = configuracao.ativo(ConfiguracaoService.PERMITIR_ESTOQUE_NEGATIVO);
        return jdbc.sql(sql).params(params)
                .query((rs, n) -> new ItemDisponivel(rs.getObject("id", UUID.class), rs.getString("nome"),
                        rs.getString("descricao"), rs.getBigDecimal("preco_venda"), rs.getString("imagem_url"),
                        rs.getObject("categoria_id", UUID.class), rs.getString("categoria"),
                        !permitirNegativo && rs.getBoolean("sem_saldo")))
                .list();
    }
}
