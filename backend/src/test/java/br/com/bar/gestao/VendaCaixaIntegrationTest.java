package br.com.bar.gestao;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Etapa 4 — um turno completo: caixa, vendas, desconto, troco, idempotência, cancelamento e fechamento. */
class VendaCaixaIntegrationTest extends IntegracaoBase {

    private String produto(String nome, String preco, String custo, boolean controlaEstoque) throws Exception {
        return JsonPath.read(corpo(postJson("/api/admin/produtos", """
                {"nome":"%s %s","tipo":"REVENDA","unidadeEstoqueId":"%s","custoMedio":%s,"precoVenda":%s,
                 "estoqueMinimo":0,"controlaEstoque":%s}""".formatted(nome, UUID.randomUUID(), idUnidade("un"), custo,
                preco, controlaEstoque)).andExpect(status().isCreated())), "$.id");
    }

    private String venda(String chave, String itens, String extras) {
        return "{\"chaveIdempotencia\":\"%s\",\"itens\":[%s],%s}".formatted(chave, itens, extras);
    }

    private static String item(String produtoId, int quantidade) {
        return "{\"produtoId\":\"%s\",\"quantidade\":%d}".formatted(produtoId, quantidade);
    }

    @Test
    void turnoCompleto() throws Exception {
        // Garante que não há caixa aberto deixado por outro teste
        if (mvcStatus("/api/admin/caixa/atual") == 200) {
            postJson("/api/admin/caixa/fechar", "{\"saldoContado\":0}").andExpect(status().isOk());
        }
        String cerveja = produto("Cerveja", "8", "3.5", true);
        String porcao = produto("Porção de fritas", "30", "9", false);
        postJson("/api/admin/estoque/entradas", "{\"produtoId\":\"%s\",\"quantidade\":10}".formatted(cerveja))
                .andExpect(status().isCreated());

        // Sem caixa aberto não há venda
        postJson("/api/admin/vendas", venda(UUID.randomUUID().toString(), item(cerveja, 1), "\"formaPagamento\":\"PIX\""))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.codigo").value("CAIXA_FECHADO"));

        String caixaId = JsonPath.read(corpo(postJson("/api/admin/caixa/abrir", "{\"saldoInicial\":100}")
                .andExpect(status().isCreated())), "$.id");
        postJson("/api/admin/caixa/abrir", "{\"saldoInicial\":0}")
                .andExpect(jsonPath("$.codigo").value("CAIXA_JA_ABERTO"));

        // 2 cervejas (16) + 1 porção (30) = 46; desconto 6 → 40; dinheiro 50 → troco 10
        String chave = UUID.randomUUID().toString();
        String pedido = venda(chave, item(cerveja, 2) + "," + item(porcao, 1),
                "\"desconto\":6,\"formaPagamento\":\"DINHEIRO\",\"valorRecebido\":50");
        String vendaDinheiro = corpo(postJson("/api/admin/vendas", pedido)
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.subtotal").value(46.0))
                .andExpect(jsonPath("$.total").value(40.0))
                .andExpect(jsonPath("$.troco").value(10.0))
                .andExpect(jsonPath("$.custoTotal").value(16.0))
                .andExpect(jsonPath("$.lucroBruto").value(24.0))
                .andExpect(jsonPath("$.margemPercentual").value(60.0))
                .andExpect(jsonPath("$.itens[0].precoUnitario").value(8.0)));
        long numero = ((Number) JsonPath.read(vendaDinheiro, "$.numero")).longValue();

        // Reenvio da mesma venda (duplo clique) não duplica nem baixa o estoque de novo
        postJson("/api/admin/vendas", pedido).andExpect(jsonPath("$.numero").value(numero));
        getAuth("/api/admin/produtos/{id}", cerveja).andExpect(jsonPath("$.estoqueAtual").value(8));

        // PIX com 10% de desconto: 8 → 7,20
        String vendaPix = JsonPath.read(corpo(postJson("/api/admin/vendas", venda(UUID.randomUUID().toString(),
                item(cerveja, 1), "\"descontoPercentual\":10,\"formaPagamento\":\"PIX\""))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.total").value(7.2))
                .andExpect(jsonPath("$.troco").doesNotExist())), "$.id");

        // Estoque insuficiente desfaz a venda inteira; produto sem controle não usa estoque
        postJson("/api/admin/vendas", venda(UUID.randomUUID().toString(), item(porcao, 1) + "," + item(cerveja, 20),
                "\"formaPagamento\":\"PIX\""))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.codigo").value("ESTOQUE_INSUFICIENTE"));
        postJson("/api/admin/estoque/entradas", "{\"produtoId\":\"%s\",\"quantidade\":1}".formatted(porcao))
                .andExpect(jsonPath("$.codigo").value("PRODUTO_SEM_CONTROLE_ESTOQUE"));

        // Suprimento e retirada; retirada maior que o dinheiro na gaveta é recusada
        postJson("/api/admin/caixa/movimentacoes", "{\"tipo\":\"SUPRIMENTO\",\"valor\":20,\"motivo\":\"troco\"}")
                .andExpect(status().isOk());
        postJson("/api/admin/caixa/movimentacoes", "{\"tipo\":\"RETIRADA\",\"valor\":1000,\"motivo\":\"x\"}")
                .andExpect(jsonPath("$.codigo").value("SALDO_INSUFICIENTE"));
        postJson("/api/admin/caixa/movimentacoes", "{\"tipo\":\"RETIRADA\",\"valor\":30,\"motivo\":\"sangria\"}")
                .andExpect(status().isOk());

        // Cancelamento com estorno do estoque
        postJson("/api/admin/vendas/" + vendaPix + "/cancelar", "{\"motivo\":\"cliente desistiu\"}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CANCELADA"));
        postJson("/api/admin/vendas/" + vendaPix + "/cancelar", "{\"motivo\":\"de novo\"}")
                .andExpect(jsonPath("$.codigo").value("VENDA_JA_CANCELADA"));
        getAuth("/api/admin/produtos/{id}", cerveja).andExpect(jsonPath("$.estoqueAtual").value(8));

        // Totais do caixa: só vendas concluídas; esperado em dinheiro = 100 + 40 + 20 − 30 = 130
        getAuth("/api/admin/caixa/atual")
                .andExpect(jsonPath("$.totais.quantidadeVendas").value(1))
                .andExpect(jsonPath("$.totais.totalVendas").value(40.0))
                .andExpect(jsonPath("$.totais.dinheiro").value(40.0))
                .andExpect(jsonPath("$.totais.pix").value(0))
                .andExpect(jsonPath("$.totais.saldoEsperado").value(130.0))
                .andExpect(jsonPath("$.vendasCanceladas").value(1))
                .andExpect(jsonPath("$.movimentacoes.length()").value(2));

        // Fechamento: contou 125 → diferença −5
        postJson("/api/admin/caixa/fechar", "{\"saldoContado\":125,\"observacao\":\"fim do turno\"}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("FECHADO"))
                .andExpect(jsonPath("$.diferenca").value(-5.0));
        getAuth("/api/admin/caixa/atual").andExpect(status().isNoContent());

        // Depois de fechado: não cancela nem vende
        String vendaDinheiroId = JsonPath.read(vendaDinheiro, "$.id");
        postJson("/api/admin/vendas/" + vendaDinheiroId + "/cancelar", "{\"motivo\":\"tarde demais\"}")
                .andExpect(jsonPath("$.codigo").value("CAIXA_FECHADO"));
        postJson("/api/admin/vendas", venda(UUID.randomUUID().toString(), item(cerveja, 1), "\"formaPagamento\":\"PIX\""))
                .andExpect(jsonPath("$.codigo").value("CAIXA_FECHADO"));

        // Histórico e caixa fechado com totais congelados
        getAuth("/api/admin/vendas?caixaId={id}", caixaId)
                .andExpect(jsonPath("$.totalElementos").value(2))
                .andExpect(jsonPath("$.conteudo[1].itens").value(org.hamcrest.Matchers.containsString("2× Cerveja")));
        getAuth("/api/admin/caixa/{id}", caixaId)
                .andExpect(jsonPath("$.totais.saldoEsperado").value(130.0))
                .andExpect(jsonPath("$.saldoContado").value(125.0));
    }

    @Test
    void catalogoDoPdvMostraSoProdutosVendaveisComPreco() throws Exception {
        String porcao = produto("Porção catálogo", "25", "7", false);
        getAuth("/api/admin/vendas/catalogo")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.produtoId == '%s')].controlaEstoque".formatted(porcao)).value(false))
                .andExpect(jsonPath("$[?(@.produtoId == '%s')].disponivel".formatted(porcao)).value(
                        org.hamcrest.Matchers.contains(org.hamcrest.Matchers.nullValue())));
    }

    private int mvcStatus(String url) throws Exception {
        return getAuth(url).andReturn().getResponse().getStatus();
    }
}
