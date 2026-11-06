package br.com.bar.gestao.compra.application;

import br.com.bar.gestao.compra.api.dto.CompraDto;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/** Consultas de leitura de compras: sugestões de reposição e histórico de preços. */
@Service
@Transactional(readOnly = true)
public class CompraConsultaService {

    private final JdbcClient jdbc;

    public CompraConsultaService(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * Produtos ativos, com controle de estoque, abaixo do mínimo. Sugestão = mínimo − saldo atual
     * (na unidade de estoque) e, se houver embalagem, a mesma quantidade arredondada para cima em
     * embalagens da maior embalagem cadastrada.
     */
    public List<CompraDto.Sugestao> sugestoes() {
        return jdbc.sql("""
                        SELECT p.id, p.nome, c.nome AS categoria, u.sigla, e.quantidade, p.estoque_minimo, p.custo_medio,
                               f.id AS fornecedor_id, coalesce(f.nome_fantasia, f.nome) AS fornecedor,
                               emb.descricao AS embalagem, emb.fator
                        FROM produto p
                        JOIN estoque e ON e.produto_id = p.id
                        JOIN unidade_medida u ON u.id = p.unidade_estoque_id
                        LEFT JOIN categoria c ON c.id = p.categoria_id
                        LEFT JOIN fornecedor f ON f.id = p.fornecedor_principal_id
                        LEFT JOIN LATERAL (
                            SELECT pe.descricao, pe.fator FROM produto_embalagem pe
                            WHERE pe.produto_id = p.id ORDER BY pe.fator DESC LIMIT 1
                        ) emb ON TRUE
                        WHERE p.ativo AND p.controla_estoque AND p.estoque_minimo > 0
                          AND e.quantidade < p.estoque_minimo
                        ORDER BY coalesce(f.nome_fantasia, f.nome, '~'), lower(p.nome)
                        """)
                .query((rs, n) -> {
                    BigDecimal atual = rs.getBigDecimal("quantidade");
                    BigDecimal minimo = rs.getBigDecimal("estoque_minimo");
                    BigDecimal sugerido = minimo.subtract(atual);
                    BigDecimal fator = rs.getBigDecimal("fator");
                    BigDecimal emEmbalagens = fator == null ? null : sugerido.divide(fator, 0, RoundingMode.CEILING);
                    return new CompraDto.Sugestao(rs.getObject("id", UUID.class), rs.getString("nome"),
                            rs.getString("categoria"), rs.getString("sigla"), atual, minimo, sugerido,
                            rs.getBigDecimal("custo_medio"), rs.getObject("fornecedor_id", UUID.class),
                            rs.getString("fornecedor"), rs.getString("embalagem"), emEmbalagens);
                })
                .list();
    }

    /** Produtos que podem ser comprados (ativos, com controle de estoque), com suas embalagens. */
    public List<CompraDto.OpcaoProduto> produtosCompraveis() {
        record Emb(UUID produtoId, CompraDto.OpcaoEmbalagem embalagem) {
        }
        java.util.Map<UUID, List<CompraDto.OpcaoEmbalagem>> embalagens = jdbc.sql("""
                        SELECT pe.produto_id, pe.id, pe.descricao, pe.fator
                        FROM produto_embalagem pe JOIN produto p ON p.id = pe.produto_id
                        WHERE p.ativo AND p.controla_estoque
                        ORDER BY pe.fator DESC
                        """)
                .query((rs, n) -> new Emb(rs.getObject("produto_id", UUID.class), new CompraDto.OpcaoEmbalagem(
                        rs.getObject("id", UUID.class), rs.getString("descricao"), rs.getBigDecimal("fator"))))
                .list().stream()
                .collect(java.util.stream.Collectors.groupingBy(Emb::produtoId,
                        java.util.stream.Collectors.mapping(Emb::embalagem, java.util.stream.Collectors.toList())));
        return jdbc.sql("""
                        SELECT p.id, p.nome, p.unidade_estoque_id, u.sigla, u.grandeza, p.custo_medio, p.fornecedor_principal_id
                        FROM produto p JOIN unidade_medida u ON u.id = p.unidade_estoque_id
                        WHERE p.ativo AND p.controla_estoque
                        ORDER BY lower(p.nome)
                        """)
                .query((rs, n) -> {
                    UUID id = rs.getObject("id", UUID.class);
                    return new CompraDto.OpcaoProduto(id, rs.getString("nome"), rs.getObject("unidade_estoque_id", UUID.class),
                            rs.getString("sigla"), rs.getString("grandeza"), rs.getBigDecimal("custo_medio"),
                            rs.getObject("fornecedor_principal_id", UUID.class), embalagens.getOrDefault(id, List.of()));
                })
                .list();
    }

    /** Preços de aquisição de um produto, do mais recente ao mais antigo. */
    public List<CompraDto.HistoricoCusto> historicoCustos(UUID produtoId) {
        return jdbc.sql("""
                        SELECT h.data_hora, c.numero, coalesce(f.nome_fantasia, f.nome) AS fornecedor, h.quantidade,
                               h.custo_unitario, h.custo_medio_anterior, h.custo_medio_novo
                        FROM historico_custo h
                        JOIN compra c ON c.id = h.compra_id
                        LEFT JOIN fornecedor f ON f.id = h.fornecedor_id
                        WHERE h.produto_id = :produtoId
                        ORDER BY h.data_hora DESC
                        LIMIT 100
                        """)
                .param("produtoId", produtoId)
                .query((rs, n) -> new CompraDto.HistoricoCusto(
                        rs.getObject("data_hora", OffsetDateTime.class).toInstant(), rs.getLong("numero"),
                        rs.getString("fornecedor"), rs.getBigDecimal("quantidade"), rs.getBigDecimal("custo_unitario"),
                        rs.getBigDecimal("custo_medio_anterior"), rs.getBigDecimal("custo_medio_novo")))
                .list();
    }
}
