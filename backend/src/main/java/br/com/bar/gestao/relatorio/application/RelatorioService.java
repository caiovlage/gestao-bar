package br.com.bar.gestao.relatorio.application;

import br.com.bar.gestao.configuracao.application.ConfiguracaoService;
import br.com.bar.gestao.relatorio.api.dto.RelatorioDto;
import br.com.bar.gestao.shared.exception.NegocioException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.List;

/**
 * Dashboard e relatórios gerenciais. Com "Dados de demonstração" ligado em Configurações,
 * devolve dados simulados; desligado, calcula a partir das vendas, despesas e estoque reais.
 */
@Service
@Transactional(readOnly = true)
public class RelatorioService {

    private static final long MAXIMO_DIAS = 400;

    private final JdbcClient jdbc;
    private final ConfiguracaoService configuracao;
    private final ZoneId fuso;

    public RelatorioService(JdbcClient jdbc, ConfiguracaoService configuracao, @Value("${app.fuso-horario}") String fuso) {
        this.jdbc = jdbc;
        this.configuracao = configuracao;
        this.fuso = ZoneId.of(fuso);
    }

    public LocalDate hoje() {
        return LocalDate.now(fuso);
    }

    public RelatorioDto.Painel painel(LocalDate inicio, LocalDate fim) {
        if (fim.isBefore(inicio)) {
            throw new NegocioException("PERIODO_INVALIDO", "A data final é anterior à inicial.");
        }
        if (ChronoUnit.DAYS.between(inicio, fim) >= MAXIMO_DIAS) {
            throw new NegocioException("PERIODO_INVALIDO", "Consulte no máximo " + MAXIMO_DIAS + " dias por vez.");
        }
        if (configuracao.ativo(ConfiguracaoService.DADOS_DEMONSTRACAO)) {
            return DadosDemonstracao.painel(inicio, fim, hoje());
        }
        return real(inicio, fim);
    }

    // ---------------------------------------------------------------- dados reais

    private record Soma(BigDecimal faturamento, BigDecimal custo, long vendas) {
    }

    private RelatorioDto.Painel real(LocalDate inicio, LocalDate fim) {
        Agregador agregador = new Agregador(inicio, fim);
        jdbc.sql("""
                        SELECT (v.data_hora AT TIME ZONE :fuso) AS local, v.forma_pagamento, v.total, v.lucro_bruto
                        FROM venda v
                        WHERE v.status = 'CONCLUIDA' AND v.data_hora >= :inicio AND v.data_hora < :fim
                        """)
                .param("fuso", fuso.getId()).param("inicio", instante(inicio)).param("fim", instante(fim.plusDays(1)))
                .query(rs -> {
                    LocalDateTime local = rs.getObject("local", LocalDateTime.class);
                    agregador.venda(local.toLocalDate(), local.getHour(), rs.getString("forma_pagamento"),
                            rs.getBigDecimal("total"), rs.getBigDecimal("lucro_bruto"));
                });
        jdbc.sql("""
                        SELECT i.produto_nome, c.nome AS categoria, i.quantidade, i.total, i.custo_total
                        FROM venda_item i
                        JOIN venda v ON v.id = i.venda_id
                        LEFT JOIN produto p ON p.id = i.produto_id
                        LEFT JOIN categoria c ON c.id = p.categoria_id
                        WHERE v.status = 'CONCLUIDA' AND v.data_hora >= :inicio AND v.data_hora < :fim
                        """)
                .param("inicio", instante(inicio)).param("fim", instante(fim.plusDays(1)))
                .query(rs -> {
                    agregador.item(rs.getString("produto_nome"), rs.getString("categoria"), rs.getBigDecimal("quantidade"),
                            rs.getBigDecimal("total"), rs.getBigDecimal("custo_total"));
                });

        long dias = ChronoUnit.DAYS.between(inicio, fim) + 1;
        Soma periodo = somar(inicio, fim);
        Soma anterior = somar(inicio.minusDays(dias), inicio.minusDays(1));
        LocalDate hoje = hoje();
        Soma doDia = somar(hoje, hoje);
        Soma doMes = somar(hoje.withDayOfMonth(1), hoje);
        BigDecimal despesas = jdbc.sql("SELECT coalesce(sum(valor), 0) FROM despesa WHERE data BETWEEN :inicio AND :fim")
                .param("inicio", inicio).param("fim", fim).query(BigDecimal.class).single();

        BigDecimal lucro = periodo.faturamento().subtract(periodo.custo());
        RelatorioDto.Indicadores indicadores = new RelatorioDto.Indicadores(
                Agregador.din(periodo.faturamento()), periodo.vendas(),
                periodo.vendas() == 0 ? BigDecimal.ZERO
                        : periodo.faturamento().divide(BigDecimal.valueOf(periodo.vendas()), 2, RoundingMode.HALF_UP),
                Agregador.din(periodo.custo()), Agregador.din(lucro), Agregador.percentual(lucro, periodo.faturamento()),
                Agregador.din(despesas), Agregador.din(lucro.subtract(despesas)),
                Agregador.variacao(periodo.faturamento(), anterior.faturamento()),
                Agregador.din(doDia.faturamento()), doDia.vendas(), Agregador.din(doMes.faturamento()), doMes.vendas());

        List<RelatorioDto.ProdutoRanking> produtos = agregador.produtos();
        return new RelatorioDto.Painel(false, inicio, fim, indicadores, agregador.serieDiaria(),
                agregador.serieHoraria(), agregador.formas(), agregador.categorias(),
                Agregador.maisVendidos(produtos), Agregador.maisLucrativos(produtos), baixoGiro(inicio, fim), estoque());
    }

    private Soma somar(LocalDate inicio, LocalDate fim) {
        return jdbc.sql("""
                        SELECT coalesce(sum(total), 0) AS faturamento, coalesce(sum(custo_total), 0) AS custo, count(*) AS qtd
                        FROM venda WHERE status = 'CONCLUIDA' AND data_hora >= :inicio AND data_hora < :fim
                        """)
                .param("inicio", instante(inicio)).param("fim", instante(fim.plusDays(1)))
                .query((rs, n) -> new Soma(rs.getBigDecimal("faturamento"), rs.getBigDecimal("custo"), rs.getLong("qtd")))
                .single();
    }

    /** Produtos vendáveis ativos que menos venderam no período (inclui os que não venderam nada). */
    private List<RelatorioDto.ProdutoGiro> baixoGiro(LocalDate inicio, LocalDate fim) {
        return jdbc.sql("""
                        SELECT p.nome, coalesce(s.qtd, 0) AS vendida, p.controla_estoque, coalesce(e.quantidade, 0) AS estoque,
                               u.sigla, p.custo_medio
                        FROM produto p
                        JOIN unidade_medida u ON u.id = p.unidade_estoque_id
                        LEFT JOIN estoque e ON e.produto_id = p.id
                        LEFT JOIN (
                            SELECT i.produto_id, sum(i.quantidade) AS qtd
                            FROM venda_item i JOIN venda v ON v.id = i.venda_id
                            WHERE v.status = 'CONCLUIDA' AND v.data_hora >= :inicio AND v.data_hora < :fim
                            GROUP BY i.produto_id
                        ) s ON s.produto_id = p.id
                        WHERE p.ativo AND p.tipo <> 'INGREDIENTE'
                        ORDER BY coalesce(s.qtd, 0), lower(p.nome)
                        LIMIT 10
                        """)
                .param("inicio", instante(inicio)).param("fim", instante(fim.plusDays(1)))
                .query((rs, n) -> {
                    boolean controla = rs.getBoolean("controla_estoque");
                    BigDecimal estoque = controla ? rs.getBigDecimal("estoque") : null;
                    BigDecimal parado = controla && estoque.signum() > 0
                            ? Agregador.din(estoque.multiply(rs.getBigDecimal("custo_medio"))) : BigDecimal.ZERO;
                    return new RelatorioDto.ProdutoGiro(rs.getString("nome"), rs.getBigDecimal("vendida").stripTrailingZeros(),
                            estoque, rs.getString("sigla"), parado);
                })
                .list();
    }

    private RelatorioDto.EstoqueResumo estoque() {
        BigDecimal valor = jdbc.sql("""
                        SELECT coalesce(sum(e.quantidade * p.custo_medio), 0)
                        FROM produto p JOIN estoque e ON e.produto_id = p.id
                        WHERE p.ativo AND p.controla_estoque AND e.quantidade > 0
                        """).query(BigDecimal.class).single();
        String filtro = """
                FROM produto p JOIN estoque e ON e.produto_id = p.id JOIN unidade_medida u ON u.id = p.unidade_estoque_id
                WHERE p.ativo AND p.controla_estoque AND p.estoque_minimo > 0 AND e.quantidade < p.estoque_minimo
                """;
        long quantidade = jdbc.sql("SELECT count(*) " + filtro).query(Long.class).single();
        List<RelatorioDto.ItemEstoque> itens = jdbc.sql("SELECT p.nome, e.quantidade, p.estoque_minimo, u.sigla " + filtro
                        + " ORDER BY e.quantidade / p.estoque_minimo, lower(p.nome) LIMIT 10")
                .query((rs, n) -> new RelatorioDto.ItemEstoque(rs.getString("nome"), rs.getBigDecimal("quantidade"),
                        rs.getBigDecimal("estoque_minimo"), rs.getString("sigla")))
                .list();
        return new RelatorioDto.EstoqueResumo(Agregador.din(valor), quantidade, itens);
    }

    private OffsetDateTime instante(LocalDate dia) {
        return dia.atStartOfDay(fuso).toOffsetDateTime().withOffsetSameInstant(ZoneOffset.UTC);
    }
}
