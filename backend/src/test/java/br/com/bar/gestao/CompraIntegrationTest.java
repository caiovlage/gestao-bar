package br.com.bar.gestao;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Etapa 5 — sugestão de reposição, lista de compras, exportação, recebimento e custo médio ponderado. */
class CompraIntegrationTest extends IntegracaoBase {

    @Test
    void reposicaoDaCervejaDaEspecificacao() throws Exception {
        // Exemplo da especificação: estoque 12 latas, mínimo 48 → sugestão de 36 (3 caixas de 12)
        String nome = "Cerveja lata " + UUID.randomUUID();
        String id = JsonPath.read(corpo(postJson("/api/admin/produtos", """
                {"nome":"%s","tipo":"REVENDA","unidadeEstoqueId":"%s","custoMedio":3,"precoVenda":8,"estoqueMinimo":48,
                 "embalagens":[{"unidadeId":"%s","descricao":"Caixa 12","fator":12}]}
                """.formatted(nome, idUnidade("un"), idUnidade("cx"))).andExpect(status().isCreated())), "$.id");
        postJson("/api/admin/estoque/entradas", "{\"produtoId\":\"%s\",\"quantidade\":12}".formatted(id))
                .andExpect(status().isCreated());

        getAuth("/api/admin/compras/sugestoes")
                .andExpect(jsonPath("$[?(@.produtoId == '%s')].sugerido".formatted(id)).value(36.0))
                .andExpect(jsonPath("$[?(@.produtoId == '%s')].embalagem".formatted(id)).value("Caixa 12"))
                .andExpect(jsonPath("$[?(@.produtoId == '%s')].sugeridoEmbalagens".formatted(id)).value(3));

        // Lista gerada da sugestão: 3 caixas pelo custo atual (3,00 × 12 = 36,00 a caixa)
        String compra = corpo(postJson("/api/admin/compras/da-sugestao", "{\"produtoIds\":[\"%s\"]}".formatted(id))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("RASCUNHO"))
                .andExpect(jsonPath("$.itens[0].quantidade").value(3))
                .andExpect(jsonPath("$.itens[0].unidadeCompra").value("Caixa 12"))
                .andExpect(jsonPath("$.itens[0].quantidadeEstoque").value(36))
                .andExpect(jsonPath("$.itens[0].custoUnitario").value(36.0)));
        String compraId = JsonPath.read(compra, "$.id");
        String embalagemId = JsonPath.read(compra, "$.itens[0].embalagemId");

        // O fornecedor cobrou R$ 43,20 a caixa (R$ 3,60 a lata)
        mvc.perform(put("/api/admin/compras/{id}", compraId).header("Authorization", token)
                        .contentType(MediaType.APPLICATION_JSON).content("""
                                {"observacao":"pedido por telefone","itens":[
                                  {"produtoId":"%s","quantidade":3,"embalagemId":"%s","custoUnitario":43.20}]}
                                """.formatted(id, embalagemId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.total").value(129.6));

        // Exportação
        byte[] pdf = getAuth("/api/admin/compras/{id}/exportar?formato=pdf", compraId)
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_PDF))
                .andReturn().getResponse().getContentAsByteArray();
        assertThat(new String(pdf, 0, 5)).isEqualTo("%PDF-");
        byte[] xlsx = getAuth("/api/admin/compras/{id}/exportar?formato=xlsx", compraId)
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsByteArray();
        assertThat(new String(xlsx, 0, 2)).isEqualTo("PK"); // .xlsx é um arquivo ZIP

        // Recebimento: +36 no estoque; custo médio = (12 × 3,00 + 36 × 3,60) ÷ 48 = 3,45
        postJson("/api/admin/compras/" + compraId + "/receber", "{}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("RECEBIDA"));
        getAuth("/api/admin/produtos/{id}", id)
                .andExpect(jsonPath("$.estoqueAtual").value(48))
                .andExpect(jsonPath("$.custoMedio").value(3.45));
        getAuth("/api/admin/compras/historico-custos?produtoId={id}", id)
                .andExpect(jsonPath("$[0].custoUnitario").value(3.6))
                .andExpect(jsonPath("$[0].custoMedioAnterior").value(3.0))
                .andExpect(jsonPath("$[0].custoMedioNovo").value(3.45));
        getAuth("/api/admin/estoque/movimentacoes?produtoId={id}", id)
                .andExpect(jsonPath("$.conteudo[0].tipo").value("ENTRADA_COMPRA"))
                .andExpect(jsonPath("$.conteudo[0].quantidadeInformada").value("3 × Caixa 12"));

        // Não recebe duas vezes nem edita depois de recebida; saiu das sugestões
        postJson("/api/admin/compras/" + compraId + "/receber", "{}")
                .andExpect(jsonPath("$.codigo").value("COMPRA_ENCERRADA"));
        getAuth("/api/admin/compras/sugestoes")
                .andExpect(jsonPath("$[?(@.produtoId == '%s')]".formatted(id)).isEmpty());
    }

    @Test
    void pratoSemControleDeEstoqueNaoEntraEmCompras() throws Exception {
        String prato = JsonPath.read(corpo(postJson("/api/admin/produtos", """
                {"nome":"Porção %s","tipo":"REVENDA","unidadeEstoqueId":"%s","custoMedio":9,"precoVenda":30,
                 "estoqueMinimo":0,"controlaEstoque":false}""".formatted(UUID.randomUUID(), idUnidade("un")))), "$.id");
        postJson("/api/admin/compras", """
                {"itens":[{"produtoId":"%s","quantidade":1,"custoUnitario":9}]}""".formatted(prato))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.codigo").value("PRODUTO_SEM_CONTROLE_ESTOQUE"));
    }
}
