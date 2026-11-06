package br.com.bar.gestao.venda.application;

import br.com.bar.gestao.shared.api.PageResponse;
import br.com.bar.gestao.venda.api.dto.VendaDto;
import br.com.bar.gestao.venda.domain.FormaPagamento;
import br.com.bar.gestao.venda.domain.Venda;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Pageable;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/** Consultas de leitura: catálogo do PDV e histórico de vendas. */
@Service
@Transactional(readOnly = true)
public class VendaConsultaService {

    private final JdbcClient jdbc;
    private final ZoneId fuso;

    public VendaConsultaService(JdbcClient jdbc, @Value("${app.fuso-horario}") String fuso) {
        this.jdbc = jdbc;
        this.fuso = ZoneId.of(fuso);
    }

    public record Filtro(LocalDate inicio, LocalDate fim, Venda.Status status, UUID caixaId, Long numero) {
    }

    /** Produtos vendáveis, ativos e com preço, ordenados por categoria (ordem do cadastro) e nome. */
    public List<VendaDto.ItemCatalogo> catalogo() {
        return jdbc.sql("""
                        SELECT p.id, p.nome, p.preco_venda, p.imagem_url, p.codigo_interno, p.controla_estoque,
                               (p.preco_promocional IS NOT NULL AND p.preco_promocional < p.preco_venda
                                AND (p.promocao_ate IS NULL OR p.promocao_ate >= :hoje)) AS em_promocao,
                               p.preco_promocional,
                               c.id AS categoria_id, c.nome AS categoria, u.sigla,
                               e.quantidade - e.quantidade_reservada AS disponivel
                        FROM produto p
                        JOIN unidade_medida u ON u.id = p.unidade_estoque_id
                        LEFT JOIN categoria c ON c.id = p.categoria_id
                        LEFT JOIN estoque e ON e.produto_id = p.id
                        WHERE p.ativo AND p.tipo <> 'INGREDIENTE' AND p.preco_venda IS NOT NULL
                        ORDER BY coalesce(c.ordem, 9999), lower(coalesce(c.nome, '')), lower(p.nome)
                        """)
                .param("hoje", LocalDate.now(fuso))
                .query((rs, n) -> {
                    boolean controla = rs.getBoolean("controla_estoque");
                    boolean promocao = rs.getBoolean("em_promocao");
                    return new VendaDto.ItemCatalogo(rs.getObject("id", UUID.class), rs.getString("nome"),
                            promocao ? rs.getBigDecimal("preco_promocional") : rs.getBigDecimal("preco_venda"), rs.getObject("categoria_id", UUID.class),
                            rs.getString("categoria"), rs.getString("imagem_url"), rs.getString("codigo_interno"),
                            controla, controla ? rs.getBigDecimal("disponivel") : null, rs.getString("sigla"),
                            promocao ? rs.getBigDecimal("preco_venda") : null);
                })
                .list();
    }

    public PageResponse<VendaDto.Resumo> pesquisar(Filtro filtro, Pageable pageable) {
        Map<String, Object> params = new HashMap<>();
        StringBuilder where = new StringBuilder(" WHERE 1 = 1");
        if (filtro.inicio() != null) {
            where.append(" AND v.data_hora >= :inicio");
            params.put("inicio", inicioDoDia(filtro.inicio()));
        }
        if (filtro.fim() != null) {
            where.append(" AND v.data_hora < :fim");
            params.put("fim", inicioDoDia(filtro.fim().plusDays(1)));
        }
        if (filtro.status() != null) {
            where.append(" AND v.status = :status");
            params.put("status", filtro.status().name());
        }
        if (filtro.caixaId() != null) {
            where.append(" AND v.caixa_id = :caixaId");
            params.put("caixaId", filtro.caixaId());
        }
        if (filtro.numero() != null) {
            where.append(" AND v.numero = :numero");
            params.put("numero", filtro.numero());
        }
        long total = jdbc.sql("SELECT count(*) FROM venda v" + where).params(params).query(Long.class).single();
        params.put("limite", pageable.getPageSize());
        params.put("deslocamento", pageable.getOffset());
        List<VendaDto.Resumo> itens = jdbc.sql("""
                        SELECT v.id, v.numero, v.data_hora, v.total, v.lucro_bruto, v.forma_pagamento, v.status,
                               (SELECT count(*) FROM venda_item i WHERE i.venda_id = v.id) AS qtd,
                               (SELECT string_agg(rtrim(to_char(i.quantidade, 'FM999999990.###'), '.') || '× ' || i.produto_nome,
                                                  ', ' ORDER BY i.ordem)
                                  FROM venda_item i WHERE i.venda_id = v.id) AS itens
                        FROM venda v""" + where + " ORDER BY v.data_hora DESC LIMIT :limite OFFSET :deslocamento")
                .params(params)
                .query((rs, n) -> new VendaDto.Resumo(rs.getObject("id", UUID.class), rs.getLong("numero"),
                        rs.getObject("data_hora", OffsetDateTime.class).toInstant(), rs.getBigDecimal("total"),
                        rs.getBigDecimal("lucro_bruto"), FormaPagamento.valueOf(rs.getString("forma_pagamento")),
                        Venda.Status.valueOf(rs.getString("status")), rs.getInt("qtd"), rs.getString("itens")))
                .list();
        int tamanho = pageable.getPageSize();
        return new PageResponse<>(itens, pageable.getPageNumber(), tamanho, total, (int) ((total + tamanho - 1) / tamanho));
    }

    private OffsetDateTime inicioDoDia(LocalDate dia) {
        return dia.atStartOfDay(fuso).toOffsetDateTime().withOffsetSameInstant(ZoneOffset.UTC);
    }
}
