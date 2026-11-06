package br.com.bar.gestao;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Etapa 7 — dashboard/relatórios com dados de demonstração e com dados reais; despesas. */
class RelatorioIntegrationTest extends IntegracaoBase {

    private void demonstracao(boolean ligada) throws Exception {
        mvc.perform(put("/api/admin/configuracoes").header("Authorization", token)
                        .contentType("application/json").content("{\"dados_demonstracao\":\"%s\"}".formatted(ligada)))
                .andExpect(status().isOk());
    }

    private BigDecimal valor(String json, String caminho) {
        return new BigDecimal(String.valueOf((Object) JsonPath.read(json, caminho)));
    }

    @Test
    void dadosDeDemonstracaoSaoConsistentesEDeterministicos() throws Exception {
        demonstracao(true);
        String painel = corpo(getAuth("/api/admin/relatorios/painel?inicio=2026-10-01&fim=2026-10-31")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.demonstracao").value(true))
                .andExpect(jsonPath("$.vendasPorDia.length()").value(31))
                .andExpect(jsonPath("$.vendasPorHora.length()").value(24))
                .andExpect(jsonPath("$.maisVendidos.length()").value(10)));
        assertThat(valor(painel, "$.indicadores.faturamento")).isPositive();
        assertThat(valor(painel, "$.indicadores.lucroBruto")).isLessThan(valor(painel, "$.indicadores.faturamento"));

        // Mesmo período, mesmos números
        String deNovo = corpo(getAuth("/api/admin/relatorios/painel?inicio=2026-10-01&fim=2026-10-31"));
        assertThat(valor(deNovo, "$.indicadores.faturamento")).isEqualByComparingTo(valor(painel, "$.indicadores.faturamento"));

        // A soma diária bate com o faturamento do período
        BigDecimal soma = BigDecimal.ZERO;
        for (Object v : JsonPath.<java.util.List<Object>>read(painel, "$.vendasPorDia[*].faturamento")) {
            soma = soma.add(new BigDecimal(String.valueOf(v)));
        }
        assertThat(soma).isEqualByComparingTo(valor(painel, "$.indicadores.faturamento"));
    }

    @Test
    void dadosReaisRefletemVendasEDespesas() throws Exception {
        demonstracao(false);
        try {
            String hoje = LocalDate.now(ZoneId.of("America/Sao_Paulo")).toString();
            String url = "/api/admin/relatorios/painel?inicio=" + hoje + "&fim=" + hoje;
            String antes = corpo(getAuth(url).andExpect(jsonPath("$.demonstracao").value(false)));

            if (getAuth("/api/admin/caixa/atual").andReturn().getResponse().getStatus() == 204) {
                postJson("/api/admin/caixa/abrir", "{\"saldoInicial\":0}").andExpect(status().isCreated());
            }
            String produto = JsonPath.read(corpo(postJson("/api/admin/produtos", """
                    {"nome":"Porção relatório %s","tipo":"REVENDA","unidadeEstoqueId":"%s","custoMedio":4,"precoVenda":10,
                     "estoqueMinimo":0,"controlaEstoque":false}""".formatted(UUID.randomUUID(), idUnidade("un")))), "$.id");
            postJson("/api/admin/vendas", """
                    {"chaveIdempotencia":"%s","itens":[{"produtoId":"%s","quantidade":2}],"formaPagamento":"PIX"}
                    """.formatted(UUID.randomUUID(), produto)).andExpect(status().isCreated());
            String despesa = JsonPath.read(corpo(postJson("/api/admin/despesas", """
                    {"descricao":"Conta de luz","categoria":"LUZ","valor":50,"data":"%s"}""".formatted(hoje))
                    .andExpect(status().isCreated())), "$.id");

            String depois = corpo(getAuth(url));
            assertThat(valor(depois, "$.indicadores.faturamento").subtract(valor(antes, "$.indicadores.faturamento")))
                    .isEqualByComparingTo("20");
            assertThat(valor(depois, "$.indicadores.custo").subtract(valor(antes, "$.indicadores.custo")))
                    .isEqualByComparingTo("8");
            assertThat(valor(depois, "$.indicadores.despesas").subtract(valor(antes, "$.indicadores.despesas")))
                    .isEqualByComparingTo("50");
            assertThat(valor(depois, "$.indicadores.lucroLiquido")).isEqualByComparingTo(
                    valor(depois, "$.indicadores.lucroBruto").subtract(valor(depois, "$.indicadores.despesas")));

            getAuth("/api/admin/despesas?inicio={d}&fim={d}", hoje, hoje)
                    .andExpect(jsonPath("$.despesas[?(@.id == '%s')].categoria".formatted(despesa)).value("LUZ"));
            mvc.perform(delete("/api/admin/despesas/{id}", despesa).header("Authorization", token))
                    .andExpect(status().isNoContent());
        } finally {
            demonstracao(true);
        }
    }
}
