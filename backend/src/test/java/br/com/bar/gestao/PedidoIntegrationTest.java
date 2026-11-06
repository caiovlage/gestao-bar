package br.com.bar.gestao;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

import java.util.List;
import java.util.UUID;

import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.not;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Etapa 6 — cardápio público, pedido idempotente, reserva de estoque, pagamento gerando venda. */
class PedidoIntegrationTest extends IntegracaoBase {

    private String categoria(String nome) throws Exception {
        return JsonPath.<List<String>>read(corpo(getAuth("/api/admin/categorias")),
                "$[?(@.nome == '" + nome + "')].id").getFirst();
    }

    private String produto(String nome, String preco, boolean controlaEstoque, boolean noCardapio) throws Exception {
        return JsonPath.read(corpo(postJson("/api/admin/produtos", """
                {"nome":"%s %s","tipo":"REVENDA","unidadeEstoqueId":"%s","categoriaId":"%s","custoMedio":2,
                 "precoVenda":%s,"estoqueMinimo":0,"controlaEstoque":%s,"vendeNoCardapio":%s}"""
                .formatted(nome, UUID.randomUUID(), idUnidade("un"), categoria("Cervejas"), preco, controlaEstoque,
                        noCardapio)).andExpect(status().isCreated())), "$.id");
    }

    private ResultActions enviar(String json, String ip) throws Exception {
        return mvc.perform(post("/api/public/pedidos").header("X-Real-IP", ip)
                .contentType(MediaType.APPLICATION_JSON).content(json));
    }

    private static String pedido(String chave, String itens) {
        return """
                {"chaveIdempotencia":"%s","clienteNome":"Ana","local":"Mesa 4","itens":[%s]}""".formatted(chave, itens);
    }

    private static String item(String produtoId, int quantidade) {
        return "{\"produtoId\":\"%s\",\"quantidade\":%d,\"observacao\":\"sem gelo\"}".formatted(produtoId, quantidade);
    }

    private ResultActions configurar(String chave, String valor) throws Exception {
        return mvc.perform(put("/api/admin/configuracoes").header("Authorization", token)
                .contentType(MediaType.APPLICATION_JSON).content("{\"%s\":\"%s\"}".formatted(chave, valor)));
    }

    private Number disponivelNoPdv(String produtoId) throws Exception {
        return JsonPath.<List<Number>>read(corpo(getAuth("/api/admin/vendas/catalogo")),
                "$[?(@.produtoId == '" + produtoId + "')].disponivel").getFirst();
    }

    @Test
    void cicloCompletoDoPedido() throws Exception {
        if (getAuth("/api/admin/caixa/atual").andReturn().getResponse().getStatus() == 200) {
            postJson("/api/admin/caixa/fechar", "{\"saldoContado\":0}").andExpect(status().isOk());
        }
        String chope = produto("Chope", "12", true, true);
        String porcao = produto("Porção", "30", false, true);
        String interno = produto("Interno", "5", false, false);
        postJson("/api/admin/estoque/entradas", "{\"produtoId\":\"%s\",\"quantidade\":5}".formatted(chope))
                .andExpect(status().isCreated());

        // Cardápio público (sem login): só produtos marcados para o cardápio, sem custo
        mvc.perform(get("/api/public/cardapio"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.aberto").value(true))
                .andExpect(jsonPath("$.categorias[*].produtos[*].id", hasItem(chope)))
                .andExpect(jsonPath("$.categorias[*].produtos[*].id", not(hasItem(interno))))
                .andExpect(jsonPath("$.categorias[*].produtos[*].custoMedio").isEmpty());

        // Produto fora do cardápio é recusado; preço vem do servidor
        enviar(pedido(UUID.randomUUID().toString(), item(interno, 1)), "10.0.0.1")
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.codigo").value("PRODUTO_INDISPONIVEL"));
        enviar(pedido(UUID.randomUUID().toString(), item(chope, 0)), "10.0.0.1")
                .andExpect(status().isBadRequest());

        // 2 chopes (24) + 1 porção (30) = 54; reenvio com a mesma chave não duplica
        String chave = UUID.randomUUID().toString();
        String json = pedido(chave, item(chope, 2) + "," + item(porcao, 1));
        String criado = corpo(enviar(json, "10.0.0.1")
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.statusPreparo").value("RECEBIDO"))
                .andExpect(jsonPath("$.statusFinanceiro").value("PENDENTE"))
                .andExpect(jsonPath("$.total").value(54.0))
                .andExpect(jsonPath("$.itens[0].observacao").value("sem gelo")));
        String id = JsonPath.read(criado, "$.id");
        long numero = ((Number) JsonPath.read(criado, "$.numero")).longValue();
        enviar(json, "10.0.0.1").andExpect(jsonPath("$.numero").value(numero));

        // Cliente acompanha sem login; o painel vê em andamento
        mvc.perform(get("/api/public/pedidos/{id}", id)).andExpect(jsonPath("$.statusPreparo").value("RECEBIDO"));
        getAuth("/api/admin/pedidos/em-andamento").andExpect(jsonPath("$[*].id", hasItem(id)));

        // Recebido não reserva; o aceite reserva 2 chopes (disponível 5 → 3)
        org.junit.jupiter.api.Assertions.assertEquals(5, disponivelNoPdv(chope).intValue());
        postJson("/api/admin/pedidos/" + id + "/status", "{\"status\":\"EM_PREPARO\"}")
                .andExpect(jsonPath("$.codigo").value("STATUS_INVALIDO"));
        postJson("/api/admin/pedidos/" + id + "/aceitar", "{}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.statusPreparo").value("ACEITO"))
                .andExpect(jsonPath("$.estoqueReservado").value(true));
        org.junit.jupiter.api.Assertions.assertEquals(3, disponivelNoPdv(chope).intValue());
        postJson("/api/admin/pedidos/" + id + "/aceitar", "{}").andExpect(jsonPath("$.codigo").value("STATUS_INVALIDO"));

        postJson("/api/admin/pedidos/" + id + "/status", "{\"status\":\"PRONTO\"}").andExpect(status().isOk());
        postJson("/api/admin/pedidos/" + id + "/status", "{\"status\":\"EM_PREPARO\"}")
                .andExpect(jsonPath("$.codigo").value("STATUS_INVALIDO"));
        postJson("/api/admin/pedidos/" + id + "/status", "{\"status\":\"ENTREGUE\"}")
                .andExpect(jsonPath("$.statusPreparo").value("ENTREGUE"));

        // Pagamento exige caixa aberto
        postJson("/api/admin/pedidos/" + id + "/pagar", "{\"formaPagamento\":\"PIX\"}")
                .andExpect(jsonPath("$.codigo").value("CAIXA_FECHADO"));
        postJson("/api/admin/caixa/abrir", "{\"saldoInicial\":0}").andExpect(status().isCreated());

        // Preço mudou depois do pedido: a venda usa o preço que o cliente viu
        mvc.perform(put("/api/admin/produtos/{id}", chope).header("Authorization", token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"nome":"Chope reajustado %s","tipo":"REVENDA","unidadeEstoqueId":"%s","categoriaId":"%s",
                                 "custoMedio":2,"precoVenda":15,"estoqueMinimo":0,"controlaEstoque":true,
                                 "vendeNoCardapio":true}""".formatted(UUID.randomUUID(), idUnidade("un"),
                                categoria("Cervejas"))))
                .andExpect(status().isOk());

        String pago = corpo(postJson("/api/admin/pedidos/" + id + "/pagar",
                "{\"formaPagamento\":\"DINHEIRO\",\"valorRecebido\":60}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.statusFinanceiro").value("PAGO"))
                .andExpect(jsonPath("$.estoqueReservado").value(false)));
        String vendaId = JsonPath.read(pago, "$.vendaId");
        getAuth("/api/admin/vendas/{id}", vendaId)
                .andExpect(jsonPath("$.total").value(54.0))
                .andExpect(jsonPath("$.troco").value(6.0))
                .andExpect(jsonPath("$.itens[0].precoUnitario").value(12.0));
        // Reserva convertida em baixa: saldo 3, disponível 3
        getAuth("/api/admin/produtos/{id}", chope).andExpect(jsonPath("$.estoqueAtual").value(3));
        org.junit.jupiter.api.Assertions.assertEquals(3, disponivelNoPdv(chope).intValue());

        // Não paga duas vezes nem cancela depois de pago; sai do painel em andamento
        postJson("/api/admin/pedidos/" + id + "/pagar", "{\"formaPagamento\":\"PIX\"}")
                .andExpect(jsonPath("$.codigo").value("PEDIDO_JA_PAGO"));
        postJson("/api/admin/pedidos/" + id + "/cancelar", "{\"motivo\":\"x\"}")
                .andExpect(jsonPath("$.codigo").value("PEDIDO_JA_PAGO"));
        getAuth("/api/admin/pedidos/em-andamento").andExpect(jsonPath("$[*].id", not(hasItem(id))));

        // Cancelamento depois do aceite libera a reserva
        String outro = JsonPath.read(corpo(enviar(pedido(UUID.randomUUID().toString(), item(chope, 3)), "10.0.0.2")
                .andExpect(status().isCreated())), "$.id");
        postJson("/api/admin/pedidos/" + outro + "/aceitar", "{}").andExpect(status().isOk());
        org.junit.jupiter.api.Assertions.assertEquals(0, disponivelNoPdv(chope).intValue());
        // Esgotado no cardápio enquanto reservado
        mvc.perform(get("/api/public/cardapio"))
                .andExpect(jsonPath("$.categorias[*].produtos[?(@.id == '%s')].esgotado".formatted(chope),
                        contains(true)));
        postJson("/api/admin/pedidos/" + outro + "/cancelar", "{\"motivo\":\"cliente foi embora\"}")
                .andExpect(jsonPath("$.statusPreparo").value("CANCELADO"))
                .andExpect(jsonPath("$.statusFinanceiro").value("CANCELADO"));
        org.junit.jupiter.api.Assertions.assertEquals(3, disponivelNoPdv(chope).intValue());
        mvc.perform(get("/api/public/pedidos/{id}", outro))
                .andExpect(jsonPath("$.motivoCancelamento").value("cliente foi embora"));

        // Aceite sem estoque suficiente falha e o pedido continua recebido
        String grande = JsonPath.read(corpo(enviar(pedido(UUID.randomUUID().toString(), item(chope, 4)), "10.0.0.3")
                .andExpect(status().isCreated())), "$.id");
        postJson("/api/admin/pedidos/" + grande + "/aceitar", "{}")
                .andExpect(jsonPath("$.codigo").value("ESTOQUE_INSUFICIENTE"));
        getAuth("/api/admin/pedidos/{id}", grande).andExpect(jsonPath("$.statusPreparo").value("RECEBIDO"));

        // Cardápio fechado não aceita pedidos
        configurar("cardapio_aberto", "false").andExpect(status().isOk());
        try {
            enviar(pedido(UUID.randomUUID().toString(), item(porcao, 1)), "10.0.0.4")
                    .andExpect(jsonPath("$.codigo").value("CARDAPIO_FECHADO"));
        } finally {
            configurar("cardapio_aberto", "true").andExpect(status().isOk());
        }

        postJson("/api/admin/caixa/fechar", "{\"saldoContado\":54}").andExpect(status().isOk());
    }

    @Test
    void limitaPedidosPorIp() throws Exception {
        String porcao = produto("Porção limite", "10", false, true);
        int criados = 0;
        int status = 0;
        for (int i = 0; i < 25 && status != 429; i++) {
            status = enviar(pedido(UUID.randomUUID().toString(), item(porcao, 1)), "10.9.9.9")
                    .andReturn().getResponse().getStatus();
            if (status == 201) criados++;
        }
        org.junit.jupiter.api.Assertions.assertEquals(429, status);
        org.junit.jupiter.api.Assertions.assertEquals(20, criados);
        // Outro IP não é afetado
        enviar(pedido(UUID.randomUUID().toString(), item(porcao, 1)), "10.9.9.10").andExpect(status().isCreated());
    }
}
