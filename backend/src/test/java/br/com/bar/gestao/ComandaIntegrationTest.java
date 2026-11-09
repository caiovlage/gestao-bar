package br.com.bar.gestao;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.UUID;

import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.not;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Comandas (contas abertas): lançamentos, reserva de estoque, vínculo com o caixa e fechamento em venda. */
class ComandaIntegrationTest extends IntegracaoBase {

    private String produto(String nome, String preco, boolean controlaEstoque) throws Exception {
        return JsonPath.read(corpo(postJson("/api/admin/produtos", """
                {"nome":"%s %s","tipo":"REVENDA","unidadeEstoqueId":"%s","custoMedio":3,"precoVenda":%s,
                 "estoqueMinimo":0,"controlaEstoque":%s}""".formatted(nome, UUID.randomUUID(), idUnidade("un"), preco,
                controlaEstoque)).andExpect(status().isCreated())), "$.id");
    }

    private Number disponivel(String produtoId) throws Exception {
        return JsonPath.<List<Number>>read(corpo(getAuth("/api/admin/vendas/catalogo")),
                "$[?(@.produtoId == '" + produtoId + "')].disponivel").getFirst();
    }

    private String lancar(String comanda, String produto, int qtd) throws Exception {
        return corpo(postJson("/api/admin/comandas/" + comanda + "/itens",
                "{\"produtoId\":\"%s\",\"quantidade\":%d}".formatted(produto, qtd)));
    }

    @Test
    void contaAbertaAteOFechamento() throws Exception {
        if (getAuth("/api/admin/caixa/atual").andReturn().getResponse().getStatus() == 200) {
            postJson("/api/admin/caixa/fechar", "{\"saldoContado\":0}");
        }
        // Sem caixa aberto não abre comanda
        postJson("/api/admin/comandas", "{\"clienteNome\":\"Caio\"}")
                .andExpect(jsonPath("$.codigo").value("CAIXA_FECHADO"));
        String caixa = JsonPath.read(corpo(postJson("/api/admin/caixa/abrir", "{\"saldoInicial\":0}")
                .andExpect(status().isCreated())), "$.id");

        String cerveja = produto("Cerveja comanda", "10", true);
        String porcao = produto("Porção comanda", "40", false);
        postJson("/api/admin/estoque/entradas", "{\"produtoId\":\"%s\",\"quantidade\":5}".formatted(cerveja))
                .andExpect(status().isCreated());

        String comanda = JsonPath.read(corpo(postJson("/api/admin/comandas",
                "{\"clienteNome\":\"Caio\",\"local\":\"Bloco 3 · Apto 710\"}")
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("ABERTA"))
                .andExpect(jsonPath("$.caixaId").value(caixa))), "$.id");

        // Rodadas: 2 cervejas + 1 porção + mais 1 cerveja (soma na mesma linha) = 3×10 + 40 = 70
        lancar(comanda, cerveja, 2);
        lancar(comanda, porcao, 1);
        String depois = lancar(comanda, cerveja, 1);
        assertEquals(2, JsonPath.<List<Object>>read(depois, "$.itens").size());
        assertEquals(70.0, ((Number) JsonPath.read(depois, "$.total")).doubleValue());
        // Cervejas consumidas ficam reservadas: o PDV não vende o que já foi para a mesa
        assertEquals(2, disponivel(cerveja).intValue());
        postJson("/api/admin/comandas/" + comanda + "/itens",
                "{\"produtoId\":\"%s\",\"quantidade\":3}".formatted(cerveja))
                .andExpect(jsonPath("$.codigo").value("ESTOQUE_INSUFICIENTE"));

        // Retira 1 cerveja: reserva devolvida
        String itemCerveja = JsonPath.<List<String>>read(depois, "$.itens[?(@.produtoId == '%s')].id".formatted(cerveja))
                .getFirst();
        postJson("/api/admin/comandas/" + comanda + "/itens/" + itemCerveja + "/retirar", "{\"quantidade\":1}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.total").value(60.0));
        assertEquals(3, disponivel(cerveja).intValue());

        // Caixa não fecha com comanda aberta
        postJson("/api/admin/caixa/fechar", "{\"saldoContado\":0}")
                .andExpect(jsonPath("$.codigo").value("COMANDAS_ABERTAS"));

        // Preço muda depois do lançamento: a conta mantém o preço lançado
        getAuth("/api/admin/comandas/abertas").andExpect(jsonPath("$[*].id", hasItem(comanda)));
        String fechada = corpo(postJson("/api/admin/comandas/" + comanda + "/fechar",
                "{\"formaPagamento\":\"DINHEIRO\",\"valorRecebido\":100}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("FECHADA")));
        String venda = JsonPath.read(fechada, "$.vendaId");
        getAuth("/api/admin/vendas/{id}", venda)
                .andExpect(jsonPath("$.total").value(60.0))
                .andExpect(jsonPath("$.troco").value(40.0))
                .andExpect(jsonPath("$.caixaId").value(caixa));
        // Reserva convertida em baixa: saldo 5 − 2 = 3, disponível 3
        getAuth("/api/admin/produtos/{id}", cerveja).andExpect(jsonPath("$.estoqueAtual").value(3));
        assertEquals(3, disponivel(cerveja).intValue());

        // Fechada não aceita mais nada e sai das abertas
        postJson("/api/admin/comandas/" + comanda + "/itens",
                "{\"produtoId\":\"%s\",\"quantidade\":1}".formatted(porcao))
                .andExpect(jsonPath("$.codigo").value("COMANDA_NAO_ABERTA"));
        postJson("/api/admin/comandas/" + comanda + "/fechar", "{\"formaPagamento\":\"PIX\"}")
                .andExpect(jsonPath("$.codigo").value("COMANDA_NAO_ABERTA"));
        getAuth("/api/admin/comandas/abertas").andExpect(jsonPath("$[*].id", not(hasItem(comanda))));

        // Comanda vazia não fecha; cancelada devolve as reservas
        String outra = JsonPath.read(corpo(postJson("/api/admin/comandas", "{\"clienteNome\":\"Ana\"}")), "$.id");
        postJson("/api/admin/comandas/" + outra + "/fechar", "{\"formaPagamento\":\"PIX\"}")
                .andExpect(jsonPath("$.codigo").value("COMANDA_VAZIA"));
        lancar(outra, cerveja, 3);
        assertEquals(0, disponivel(cerveja).intValue());
        postJson("/api/admin/comandas/" + outra + "/cancelar", "{\"motivo\":\"cliente foi embora\"}")
                .andExpect(jsonPath("$.status").value("CANCELADA"));
        assertEquals(3, disponivel(cerveja).intValue());

        // Sem comandas abertas, o caixa fecha (venda da comanda soma no dinheiro esperado)
        postJson("/api/admin/caixa/fechar", "{\"saldoContado\":60}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totais.dinheiro").value(60.0))
                .andExpect(jsonPath("$.diferenca").value(0.0));
        getAuth("/api/admin/comandas?size=50").andExpect(jsonPath("$.conteudo[*].id", hasItem(comanda)));
    }
}
