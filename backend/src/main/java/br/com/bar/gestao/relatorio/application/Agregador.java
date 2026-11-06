package br.com.bar.gestao.relatorio.application;

import br.com.bar.gestao.relatorio.api.dto.RelatorioDto;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

/** Acumula vendas (reais ou simuladas) e monta as séries e rankings do painel. */
final class Agregador {

    static final BigDecimal CEM = BigDecimal.valueOf(100);

    private final Map<LocalDate, BigDecimal[]> porDia = new TreeMap<>();       // faturamento, lucro, quantidade
    private final BigDecimal[][] porHora = new BigDecimal[24][2];              // faturamento, quantidade
    private final Map<String, BigDecimal[]> porForma = new LinkedHashMap<>();  // total, quantidade
    private final Map<String, BigDecimal[]> porCategoria = new LinkedHashMap<>(); // faturamento, lucro
    private final Map<String, BigDecimal[]> porProduto = new LinkedHashMap<>(); // quantidade, faturamento, custo

    Agregador(LocalDate inicio, LocalDate fim) {
        for (LocalDate d = inicio; !d.isAfter(fim); d = d.plusDays(1)) {
            porDia.put(d, zeros(3));
        }
        for (int h = 0; h < 24; h++) {
            porHora[h] = zeros(2);
        }
    }

    void venda(LocalDate dia, int hora, String forma, BigDecimal total, BigDecimal lucro) {
        somar(porDia.computeIfAbsent(dia, d -> zeros(3)), total, lucro, BigDecimal.ONE);
        somar(porHora[hora], total, BigDecimal.ONE);
        somar(porForma.computeIfAbsent(forma, f -> zeros(2)), total, BigDecimal.ONE);
    }

    void item(String produto, String categoria, BigDecimal quantidade, BigDecimal total, BigDecimal custo) {
        somar(porProduto.computeIfAbsent(produto, p -> zeros(3)), quantidade, total, custo);
        somar(porCategoria.computeIfAbsent(categoria == null ? "Sem categoria" : categoria, c -> zeros(2)),
                total, total.subtract(custo));
    }

    List<RelatorioDto.PontoDia> serieDiaria() {
        return porDia.entrySet().stream()
                .map(e -> new RelatorioDto.PontoDia(e.getKey(), din(e.getValue()[0]), din(e.getValue()[1]),
                        e.getValue()[2].longValue()))
                .toList();
    }

    List<RelatorioDto.PontoHora> serieHoraria() {
        List<RelatorioDto.PontoHora> lista = new ArrayList<>();
        for (int h = 0; h < 24; h++) {
            lista.add(new RelatorioDto.PontoHora(h, din(porHora[h][0]), porHora[h][1].longValue()));
        }
        return lista;
    }

    List<RelatorioDto.TotalForma> formas() {
        return porForma.entrySet().stream()
                .map(e -> new RelatorioDto.TotalForma(e.getKey(), din(e.getValue()[0]), e.getValue()[1].longValue()))
                .sorted(Comparator.comparing(RelatorioDto.TotalForma::total).reversed())
                .toList();
    }

    List<RelatorioDto.TotalCategoria> categorias() {
        return porCategoria.entrySet().stream()
                .map(e -> new RelatorioDto.TotalCategoria(e.getKey(), din(e.getValue()[0]), din(e.getValue()[1])))
                .sorted(Comparator.comparing(RelatorioDto.TotalCategoria::faturamento).reversed())
                .toList();
    }

    List<RelatorioDto.ProdutoRanking> produtos() {
        return porProduto.entrySet().stream()
                .map(e -> ranking(e.getKey(), e.getValue()[0], e.getValue()[1], e.getValue()[2]))
                .toList();
    }

    static RelatorioDto.ProdutoRanking ranking(String produto, BigDecimal quantidade, BigDecimal faturamento,
                                               BigDecimal custo) {
        BigDecimal lucro = faturamento.subtract(custo);
        boolean temQtd = quantidade.signum() > 0;
        return new RelatorioDto.ProdutoRanking(produto, quantidade.stripTrailingZeros(), din(faturamento), din(custo),
                din(lucro), percentual(lucro, faturamento),
                temQtd ? faturamento.divide(quantidade, 2, RoundingMode.HALF_UP) : BigDecimal.ZERO,
                temQtd ? custo.divide(quantidade, 2, RoundingMode.HALF_UP) : BigDecimal.ZERO,
                temQtd ? lucro.divide(quantidade, 2, RoundingMode.HALF_UP) : BigDecimal.ZERO);
    }

    static List<RelatorioDto.ProdutoRanking> maisVendidos(List<RelatorioDto.ProdutoRanking> produtos) {
        return produtos.stream().sorted(Comparator.comparing(RelatorioDto.ProdutoRanking::quantidade).reversed())
                .limit(10).toList();
    }

    static List<RelatorioDto.ProdutoRanking> maisLucrativos(List<RelatorioDto.ProdutoRanking> produtos) {
        return produtos.stream().sorted(Comparator.comparing(RelatorioDto.ProdutoRanking::lucroBruto).reversed())
                .limit(10).toList();
    }

    static BigDecimal percentual(BigDecimal parte, BigDecimal todo) {
        return todo.signum() == 0 ? BigDecimal.ZERO : parte.multiply(CEM).divide(todo, 2, RoundingMode.HALF_UP);
    }

    static BigDecimal variacao(BigDecimal atual, BigDecimal anterior) {
        return anterior.signum() == 0 ? null
                : atual.subtract(anterior).multiply(CEM).divide(anterior, 1, RoundingMode.HALF_UP);
    }

    static BigDecimal din(BigDecimal v) {
        return v.setScale(2, RoundingMode.HALF_UP);
    }

    private static BigDecimal[] zeros(int n) {
        BigDecimal[] a = new BigDecimal[n];
        java.util.Arrays.fill(a, BigDecimal.ZERO);
        return a;
    }

    private static void somar(BigDecimal[] alvo, BigDecimal... valores) {
        for (int i = 0; i < valores.length; i++) {
            alvo[i] = alvo[i].add(valores[i]);
        }
    }
}
