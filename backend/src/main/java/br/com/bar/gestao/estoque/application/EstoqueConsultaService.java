package br.com.bar.gestao.estoque.application;

import br.com.bar.gestao.estoque.api.dto.EstoqueDto;
import br.com.bar.gestao.estoque.domain.OrigemMovimentacao;
import br.com.bar.gestao.estoque.domain.TipoMovimentacao;
import br.com.bar.gestao.shared.api.PageResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Pageable;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Consultas de leitura do estoque (posição, resumo e histórico), em SQL direto:
 * são relatórios que cruzam produto, saldo, categoria e unidade.
 */
@Service
@Transactional(readOnly = true)
public class EstoqueConsultaService {

    private final JdbcClient jdbc;
    private final ZoneId fuso;

    public EstoqueConsultaService(JdbcClient jdbc, @Value("${app.fuso-horario}") String fuso) {
        this.jdbc = jdbc;
        this.fuso = ZoneId.of(fuso);
    }

    public record FiltroPosicao(String nome, UUID categoriaId, EstoqueDto.Situacao situacao, Boolean ativo) {
    }

    public record FiltroMovimentacoes(UUID produtoId, TipoMovimentacao tipo, LocalDate inicio, LocalDate fim) {
    }

    // ---------------------------------------------------------------- posição

    private static final String POSICAO_FROM = """
            FROM produto p
            JOIN estoque e ON e.produto_id = p.id
            JOIN unidade_medida u ON u.id = p.unidade_estoque_id
            LEFT JOIN categoria c ON c.id = p.categoria_id
            """;

    public PageResponse<EstoqueDto.PosicaoResponse> posicao(FiltroPosicao filtro, Pageable pageable) {
        Map<String, Object> params = new HashMap<>();
        StringBuilder where = new StringBuilder(" WHERE 1 = 1");
        if (filtro.nome() != null && !filtro.nome().isBlank()) {
            where.append(" AND (lower(p.nome) LIKE :nome OR lower(coalesce(p.codigo_interno, '')) LIKE :nome)");
            params.put("nome", "%" + filtro.nome().trim().toLowerCase() + "%");
        }
        if (filtro.categoriaId() != null) {
            where.append(" AND p.categoria_id = :categoriaId");
            params.put("categoriaId", filtro.categoriaId());
        }
        if (filtro.ativo() != null) {
            where.append(" AND p.ativo = :ativo");
            params.put("ativo", filtro.ativo());
        }
        switch (filtro.situacao() == null ? EstoqueDto.Situacao.TODOS : filtro.situacao()) {
            case ABAIXO_MINIMO -> where.append(" AND p.estoque_minimo > 0 AND e.quantidade < p.estoque_minimo");
            case ZERADO -> where.append(" AND e.quantidade <= 0");
            case TODOS -> { }
        }

        long total = jdbc.sql("SELECT count(*) " + POSICAO_FROM + where).params(params).query(Long.class).single();
        params.put("limite", pageable.getPageSize());
        params.put("deslocamento", pageable.getOffset());
        List<EstoqueDto.PosicaoResponse> itens = jdbc.sql("""
                        SELECT p.id, p.nome, p.codigo_interno, p.tipo, p.ativo, p.estoque_minimo, p.custo_medio,
                               c.nome AS categoria, u.sigla, e.quantidade, e.quantidade_reservada
                        """ + POSICAO_FROM + where + " ORDER BY lower(p.nome) LIMIT :limite OFFSET :deslocamento")
                .params(params)
                .query(EstoqueConsultaService::posicaoDaLinha)
                .list();
        return pagina(itens, pageable, total);
    }

    public EstoqueDto.ResumoResponse resumo() {
        return jdbc.sql("""
                        SELECT count(*) AS ativos,
                               count(*) FILTER (WHERE p.estoque_minimo > 0 AND e.quantidade < p.estoque_minimo) AS abaixo,
                               count(*) FILTER (WHERE e.quantidade <= 0) AS zerados,
                               coalesce(sum(CASE WHEN e.quantidade > 0 THEN e.quantidade * p.custo_medio END), 0) AS valor
                        FROM produto p JOIN estoque e ON e.produto_id = p.id
                        WHERE p.ativo
                        """)
                .query((rs, n) -> new EstoqueDto.ResumoResponse(rs.getLong("ativos"), rs.getLong("abaixo"),
                        rs.getLong("zerados"), rs.getBigDecimal("valor").setScale(2, RoundingMode.HALF_UP)))
                .single();
    }

    // ---------------------------------------------------------------- movimentações

    public PageResponse<EstoqueDto.MovimentacaoResponse> movimentacoes(FiltroMovimentacoes filtro, Pageable pageable) {
        Map<String, Object> params = new HashMap<>();
        StringBuilder where = new StringBuilder(" WHERE 1 = 1");
        if (filtro.produtoId() != null) {
            where.append(" AND m.produto_id = :produtoId");
            params.put("produtoId", filtro.produtoId());
        }
        if (filtro.tipo() != null) {
            where.append(" AND m.tipo = :tipo");
            params.put("tipo", filtro.tipo().name());
        }
        if (filtro.inicio() != null) {
            where.append(" AND m.data_hora >= :inicio");
            params.put("inicio", inicioDoDia(filtro.inicio()));
        }
        if (filtro.fim() != null) {
            where.append(" AND m.data_hora < :fim");
            params.put("fim", inicioDoDia(filtro.fim().plusDays(1)));
        }
        String from = """
                 FROM movimentacao_estoque m
                 JOIN produto p ON p.id = m.produto_id
                 JOIN unidade_medida u ON u.id = p.unidade_estoque_id
                """;
        long total = jdbc.sql("SELECT count(*)" + from + where).params(params).query(Long.class).single();
        params.put("limite", pageable.getPageSize());
        params.put("deslocamento", pageable.getOffset());
        List<EstoqueDto.MovimentacaoResponse> itens = jdbc.sql("SELECT m.*, p.nome, u.sigla" + from + where
                        + " ORDER BY m.data_hora DESC, m.id LIMIT :limite OFFSET :deslocamento")
                .params(params)
                .query(EstoqueConsultaService::movimentacaoDaLinha)
                .list();
        return pagina(itens, pageable, total);
    }

    // ---------------------------------------------------------------- mapeamento

    private static EstoqueDto.PosicaoResponse posicaoDaLinha(ResultSet rs, int n) throws SQLException {
        BigDecimal quantidade = rs.getBigDecimal("quantidade");
        BigDecimal reservada = rs.getBigDecimal("quantidade_reservada");
        BigDecimal minimo = rs.getBigDecimal("estoque_minimo");
        BigDecimal custo = rs.getBigDecimal("custo_medio");
        BigDecimal valor = quantidade.signum() > 0
                ? quantidade.multiply(custo).setScale(2, RoundingMode.HALF_UP) : BigDecimal.ZERO;
        return new EstoqueDto.PosicaoResponse(rs.getObject("id", UUID.class), rs.getString("nome"),
                rs.getString("codigo_interno"), rs.getString("categoria"), rs.getString("tipo"), rs.getString("sigla"),
                quantidade, reservada, quantidade.subtract(reservada), minimo, custo, valor,
                minimo.signum() > 0 && quantidade.compareTo(minimo) < 0, rs.getBoolean("ativo"));
    }

    private static EstoqueDto.MovimentacaoResponse movimentacaoDaLinha(ResultSet rs, int n) throws SQLException {
        return new EstoqueDto.MovimentacaoResponse(rs.getObject("id", UUID.class),
                rs.getObject("produto_id", UUID.class), rs.getString("nome"), rs.getString("sigla"),
                TipoMovimentacao.valueOf(rs.getString("tipo")), rs.getBigDecimal("quantidade"),
                rs.getBigDecimal("saldo_anterior"), rs.getBigDecimal("saldo_posterior"),
                rs.getBigDecimal("custo_unitario"), rs.getString("quantidade_informada"),
                OrigemMovimentacao.valueOf(rs.getString("origem_tipo")), rs.getObject("origem_id", UUID.class),
                rs.getString("observacao"), rs.getObject("data_hora", OffsetDateTime.class).toInstant());
    }

    private OffsetDateTime inicioDoDia(LocalDate dia) {
        return dia.atStartOfDay(fuso).toOffsetDateTime().withOffsetSameInstant(ZoneOffset.UTC);
    }

    private static <T> PageResponse<T> pagina(List<T> itens, Pageable pageable, long total) {
        int tamanho = pageable.getPageSize();
        int paginas = (int) ((total + tamanho - 1) / tamanho);
        return new PageResponse<>(itens, pageable.getPageNumber(), tamanho, total, paginas);
    }
}
