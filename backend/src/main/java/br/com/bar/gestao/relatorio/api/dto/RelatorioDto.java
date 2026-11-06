package br.com.bar.gestao.relatorio.api.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * Indicadores gerenciais de um período. Faturamento considera apenas vendas concluídas
 * (pedidos e vendas canceladas não entram). Lucro bruto = vendas − custo dos produtos;
 * lucro líquido = lucro bruto − despesas registradas no período.
 */
public final class RelatorioDto {

    private RelatorioDto() {
    }

    public record Painel(
            /** true quando os dados são de demonstração (Configurações → Dados de demonstração). */
            boolean demonstracao,
            LocalDate inicio,
            LocalDate fim,
            Indicadores indicadores,
            List<PontoDia> vendasPorDia,
            List<PontoHora> vendasPorHora,
            List<TotalForma> formasPagamento,
            List<TotalCategoria> porCategoria,
            List<ProdutoRanking> maisVendidos,
            List<ProdutoRanking> maisLucrativos,
            List<ProdutoGiro> baixoGiro,
            EstoqueResumo estoque) {
    }

    public record Indicadores(
            BigDecimal faturamento,
            long quantidadeVendas,
            BigDecimal ticketMedio,
            BigDecimal custo,
            BigDecimal lucroBruto,
            BigDecimal margemBruta,
            BigDecimal despesas,
            BigDecimal lucroLiquido,
            /** Variação do faturamento em relação ao período anterior de mesma duração (%). */
            BigDecimal variacaoFaturamento,
            BigDecimal faturamentoHoje,
            long vendasHoje,
            BigDecimal faturamentoMes,
            long vendasMes) {
    }

    public record PontoDia(LocalDate data, BigDecimal faturamento, BigDecimal lucroBruto, long quantidade) {
    }

    public record PontoHora(int hora, BigDecimal faturamento, long quantidade) {
    }

    public record TotalForma(String forma, BigDecimal total, long quantidade) {
    }

    public record TotalCategoria(String categoria, BigDecimal faturamento, BigDecimal lucroBruto) {
    }

    public record ProdutoRanking(String produto, BigDecimal quantidade, BigDecimal faturamento, BigDecimal custo,
                                 BigDecimal lucroBruto, BigDecimal margem, BigDecimal precoMedio,
                                 BigDecimal custoUnitario, BigDecimal lucroUnitario) {
    }

    public record ProdutoGiro(String produto, BigDecimal quantidadeVendida, BigDecimal estoqueAtual, String unidade,
                              BigDecimal valorParado) {
    }

    public record EstoqueResumo(BigDecimal valorEstoque, long produtosAbaixoMinimo, List<ItemEstoque> abaixoMinimo) {
    }

    public record ItemEstoque(String produto, BigDecimal atual, BigDecimal minimo, String unidade) {
    }
}
