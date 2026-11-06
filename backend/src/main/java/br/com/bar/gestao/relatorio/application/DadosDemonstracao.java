package br.com.bar.gestao.relatorio.application;

import br.com.bar.gestao.relatorio.api.dto.RelatorioDto;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.Comparator;
import java.util.List;
import java.util.Random;

/**
 * Dados de demonstração para apresentações: simula, dia a dia, a operação de um bar
 * (mais movimento de quinta a sábado, pico entre 20h e 23h, produtos com preço e custo
 * realistas). É determinístico: o mesmo dia gera sempre os mesmos números.
 */
final class DadosDemonstracao {

    private record Produto(String nome, String categoria, double preco, double custo, int popularidade) {
    }

    private static final List<Produto> PRODUTOS = List.of(
            new Produto("Chopp 300 ml", "Cervejas", 9.90, 3.10, 30),
            new Produto("Cerveja long neck", "Cervejas", 12.00, 5.20, 22),
            new Produto("Cerveja lata", "Cervejas", 8.00, 3.45, 16),
            new Produto("Caipirinha de limão", "Bebidas", 22.00, 5.80, 14),
            new Produto("Gin tônica", "Bebidas", 32.00, 9.50, 9),
            new Produto("Drink da casa", "Bebidas", 28.00, 7.20, 7),
            new Produto("Refrigerante lata", "Refrigerantes", 7.00, 2.80, 12),
            new Produto("Água mineral", "Refrigerantes", 5.00, 1.40, 8),
            new Produto("Batata frita com cheddar e bacon", "Porções", 42.00, 13.50, 11),
            new Produto("Isca de frango", "Porções", 48.00, 17.00, 8),
            new Produto("Porção de calabresa", "Porções", 39.00, 12.20, 6),
            new Produto("Hambúrguer artesanal", "Lanches", 38.00, 14.80, 7),
            new Produto("Pastel (6 un.)", "Porções", 32.00, 9.00, 5),
            new Produto("Petit gâteau", "Sobremesas", 26.00, 8.50, 3));

    private static final String[] FORMAS = {"PIX", "CARTAO_CREDITO", "CARTAO_DEBITO", "DINHEIRO", "OUTROS"};
    private static final double[] PESO_FORMA = {0.44, 0.21, 0.19, 0.14, 0.02};
    /** Movimento por hora (11h às 2h), pico à noite. */
    private static final double[] PESO_HORA = new double[24];

    static {
        double[][] horas = {{11, 2}, {12, 5}, {13, 4}, {14, 2}, {15, 1}, {16, 2}, {17, 4}, {18, 7}, {19, 10},
                {20, 13}, {21, 15}, {22, 14}, {23, 10}, {0, 6}, {1, 3}};
        for (double[] h : horas) {
            PESO_HORA[(int) h[0]] = h[1];
        }
    }

    private static final int TOTAL_POPULARIDADE = PRODUTOS.stream().mapToInt(Produto::popularidade).sum();

    private DadosDemonstracao() {
    }

    static RelatorioDto.Painel painel(LocalDate inicio, LocalDate fim, LocalDate hoje) {
        Agregador agregador = new Agregador(inicio, fim);
        Totais periodo = simular(inicio, fim, agregador);
        long dias = ChronoUnit.DAYS.between(inicio, fim) + 1;
        Totais anterior = simular(inicio.minusDays(dias), inicio.minusDays(1), null);
        Totais doDia = simular(hoje, hoje, null);
        Totais doMes = simular(hoje.withDayOfMonth(1), hoje, null);

        BigDecimal despesas = BigDecimal.valueOf(16_200).multiply(BigDecimal.valueOf(dias))
                .divide(BigDecimal.valueOf(30), 2, RoundingMode.HALF_UP);
        BigDecimal lucro = periodo.faturamento.subtract(periodo.custo);
        RelatorioDto.Indicadores indicadores = new RelatorioDto.Indicadores(
                Agregador.din(periodo.faturamento), periodo.vendas,
                periodo.vendas == 0 ? BigDecimal.ZERO
                        : periodo.faturamento.divide(BigDecimal.valueOf(periodo.vendas), 2, RoundingMode.HALF_UP),
                Agregador.din(periodo.custo), Agregador.din(lucro), Agregador.percentual(lucro, periodo.faturamento),
                despesas, Agregador.din(lucro.subtract(despesas)),
                Agregador.variacao(periodo.faturamento, anterior.faturamento),
                Agregador.din(doDia.faturamento), doDia.vendas, Agregador.din(doMes.faturamento), doMes.vendas);

        List<RelatorioDto.ProdutoRanking> produtos = agregador.produtos();
        List<RelatorioDto.ProdutoGiro> baixoGiro = produtos.stream()
                .sorted(Comparator.comparing(RelatorioDto.ProdutoRanking::quantidade))
                .limit(3)
                .map(p -> new RelatorioDto.ProdutoGiro(p.produto(), p.quantidade(), BigDecimal.valueOf(14), "un",
                        BigDecimal.valueOf(14).multiply(p.custoUnitario())))
                .collect(java.util.stream.Collectors.toCollection(java.util.ArrayList::new));
        baixoGiro.add(new RelatorioDto.ProdutoGiro("Vinho tinto (garrafa)", BigDecimal.ZERO, BigDecimal.valueOf(9), "un",
                BigDecimal.valueOf(342)));
        baixoGiro.add(new RelatorioDto.ProdutoGiro("Licor de chocolate", BigDecimal.ZERO, BigDecimal.valueOf(4), "un",
                BigDecimal.valueOf(156)));

        RelatorioDto.EstoqueResumo estoque = new RelatorioDto.EstoqueResumo(BigDecimal.valueOf(18_450.90), 4, List.of(
                new RelatorioDto.ItemEstoque("Cerveja lata", BigDecimal.valueOf(12), BigDecimal.valueOf(48), "un"),
                new RelatorioDto.ItemEstoque("Limão", BigDecimal.valueOf(800), BigDecimal.valueOf(3000), "g"),
                new RelatorioDto.ItemEstoque("Batata congelada", BigDecimal.valueOf(2500), BigDecimal.valueOf(10000), "g"),
                new RelatorioDto.ItemEstoque("Gelo", BigDecimal.valueOf(5), BigDecimal.valueOf(20), "un")));

        return new RelatorioDto.Painel(true, inicio, fim, indicadores, agregador.serieDiaria(),
                agregador.serieHoraria(), agregador.formas(), agregador.categorias(),
                Agregador.maisVendidos(produtos), Agregador.maisLucrativos(produtos), baixoGiro, estoque);
    }

    private static final class Totais {
        BigDecimal faturamento = BigDecimal.ZERO;
        BigDecimal custo = BigDecimal.ZERO;
        long vendas;
    }

    /** Simula as vendas de cada dia do intervalo; se houver agregador, alimenta as séries e rankings. */
    private static Totais simular(LocalDate inicio, LocalDate fim, Agregador agregador) {
        Totais t = new Totais();
        for (LocalDate dia = inicio; !dia.isAfter(fim); dia = dia.plusDays(1)) {
            Random r = new Random(dia.toEpochDay() * 7_919L + 13);
            int vendasDoDia = (int) Math.round(42 * fatorDiaSemana(dia.getDayOfWeek()) * (0.85 + r.nextDouble() * 0.3));
            for (int v = 0; v < vendasDoDia; v++) {
                int hora = sortear(r, PESO_HORA);
                String forma = FORMAS[sortear(r, PESO_FORMA)];
                int itens = 1 + r.nextInt(3);
                BigDecimal totalVenda = BigDecimal.ZERO;
                BigDecimal custoVenda = BigDecimal.ZERO;
                for (int i = 0; i < itens; i++) {
                    Produto p = produto(r);
                    BigDecimal qtd = BigDecimal.valueOf(p.categoria().equals("Porções") ? 1 : 1 + r.nextInt(3));
                    BigDecimal total = BigDecimal.valueOf(p.preco()).multiply(qtd);
                    BigDecimal custo = BigDecimal.valueOf(p.custo()).multiply(qtd);
                    totalVenda = totalVenda.add(total);
                    custoVenda = custoVenda.add(custo);
                    if (agregador != null) agregador.item(p.nome(), p.categoria(), qtd, total, custo);
                }
                t.faturamento = t.faturamento.add(totalVenda);
                t.custo = t.custo.add(custoVenda);
                t.vendas++;
                if (agregador != null) agregador.venda(dia, hora, forma, totalVenda, totalVenda.subtract(custoVenda));
            }
        }
        return t;
    }

    private static double fatorDiaSemana(DayOfWeek d) {
        return switch (d) {
            case MONDAY -> 0.45;
            case TUESDAY -> 0.6;
            case WEDNESDAY -> 0.75;
            case THURSDAY -> 1.05;
            case FRIDAY -> 1.55;
            case SATURDAY -> 1.75;
            case SUNDAY -> 1.0;
        };
    }

    private static Produto produto(Random r) {
        int alvo = r.nextInt(TOTAL_POPULARIDADE);
        for (Produto p : PRODUTOS) {
            alvo -= p.popularidade();
            if (alvo < 0) return p;
        }
        return PRODUTOS.getFirst();
    }

    private static int sortear(Random r, double[] pesos) {
        double soma = 0;
        for (double p : pesos) soma += p;
        double alvo = r.nextDouble() * soma;
        for (int i = 0; i < pesos.length; i++) {
            alvo -= pesos[i];
            if (alvo < 0) return i;
        }
        return pesos.length - 1;
    }
}
