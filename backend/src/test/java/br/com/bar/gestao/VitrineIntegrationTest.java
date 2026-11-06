package br.com.bar.gestao;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.not;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Cardápio com destaques: promoções (com validade), sugestões da casa e vitrine configurável. */
class VitrineIntegrationTest extends IntegracaoBase {

    private String categoria() throws Exception {
        return JsonPath.<List<String>>read(corpo(getAuth("/api/admin/categorias")),
                "$[?(@.nome == 'Porções')].id").getFirst();
    }

    private String produto(String nome, String preco, String promocional, String promocaoAte, boolean destaque)
            throws Exception {
        return JsonPath.read(corpo(postJson("/api/admin/produtos", corpoProduto(nome, preco, promocional, promocaoAte,
                destaque)).andExpect(status().isCreated())), "$.id");
    }

    private String corpoProduto(String nome, String preco, String promocional, String promocaoAte, boolean destaque)
            throws Exception {
        return """
                {"nome":"%s %s","tipo":"REVENDA","unidadeEstoqueId":"%s","categoriaId":"%s","custoMedio":5,
                 "precoVenda":%s,"estoqueMinimo":0,"controlaEstoque":false,"vendeNoCardapio":true,
                 "precoPromocional":%s,"promocaoAte":%s,"destaqueCardapio":%s}"""
                .formatted(nome, UUID.randomUUID(), idUnidade("un"), categoria(), preco, promocional,
                        promocaoAte == null ? "null" : "\"" + promocaoAte + "\"", destaque);
    }

    private void vitrine(String json) throws Exception {
        mvc.perform(put("/api/admin/cardapio/vitrine").header("Authorization", token)
                .contentType(MediaType.APPLICATION_JSON).content(json)).andExpect(status().isOk());
    }

    @Test
    void promocoesSugestoesEVitrine() throws Exception {
        String hoje = LocalDate.now().toString();
        String promo = produto("Fritas promo", "30", "24", null, false);          // 20% de desconto
        String vencida = produto("Isca vencida", "40", "30", "2020-01-01", false);
        String sugestao = produto("Costela sugestão", "80", "null", null, true);
        String promoHoje = produto("Calabresa hoje", "50", "45", hoje, false);    // 10% de desconto

        // Promocional precisa ser menor que o preço
        postJson("/api/admin/produtos", corpoProduto("Inválido", "10", "10", null, false))
                .andExpect(jsonPath("$.codigo").value("PRECO_PROMOCIONAL_INVALIDO"));

        // Configuração: promoções primeiro, depois sugestões; mais pedidos desligado
        vitrine("""
                {"secoes":[
                  {"tipo":"PROMOCOES","titulo":"Happy hour","ativa":true,"quantidade":12},
                  {"tipo":"SUGESTOES","titulo":"Sugestões do chef","ativa":true,"quantidade":12},
                  {"tipo":"MAIS_PEDIDOS","titulo":"Mais pedidos","ativa":false,"quantidade":6},
                  {"tipo":"NOVIDADES","titulo":"Novidades","ativa":false,"quantidade":6},
                  {"tipo":"MENOS_PEDIDOS","titulo":"Experimente","ativa":true,"quantidade":12}]}""");
        getAuth("/api/admin/cardapio/vitrine")
                .andExpect(jsonPath("$[0].tipo").value("PROMOCOES"))
                .andExpect(jsonPath("$[0].titulo").value("Happy hour"));

        String cardapio = corpo(mvc.perform(get("/api/public/cardapio")).andExpect(status().isOk()));
        assertEquals("PROMOCOES", JsonPath.read(cardapio, "$.destaques[0].tipo"));
        assertEquals("Happy hour", JsonPath.read(cardapio, "$.destaques[0].titulo"));
        List<String> promocoes = JsonPath.read(cardapio, "$.destaques[0].produtos");
        // maior desconto primeiro; promoção vencida fora
        assertTrue(promocoes.indexOf(promo) >= 0 && promocoes.indexOf(promo) < promocoes.indexOf(promoHoje));
        assertTrue(!promocoes.contains(vencida));
        assertTrue(JsonPath.<List<String>>read(cardapio, "$.destaques[1].produtos").contains(sugestao));
        assertTrue(JsonPath.<List<String>>read(cardapio, "$.destaques[*].tipo").stream()
                .noneMatch("MAIS_PEDIDOS"::equals));
        assertTrue(JsonPath.<List<String>>read(cardapio, "$.destaques[2].produtos").contains(vencida));

        // Preço de hoje e preço original
        mvc.perform(get("/api/public/cardapio"))
                .andExpect(jsonPath("$.categorias[*].produtos[?(@.id == '%s')].preco".formatted(promo), contains(24.0)))
                .andExpect(jsonPath("$.categorias[*].produtos[?(@.id == '%s')].precoOriginal".formatted(promo),
                        contains(30.0)))
                .andExpect(jsonPath("$.categorias[*].produtos[?(@.id == '%s')].preco".formatted(vencida), contains(40.0)));

        // Pedido pelo cardápio usa o preço promocional
        mvc.perform(post("/api/public/pedidos").header("X-Real-IP", "10.7.7.7").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"chaveIdempotencia":"%s","clienteNome":"Bia","local":"Mesa 2",
                                 "itens":[{"produtoId":"%s","quantidade":2}]}""".formatted(UUID.randomUUID(), promo)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.total").value(48.0));

        // PDV também cobra o promocional e mostra o preço normal
        getAuth("/api/admin/vendas/catalogo")
                .andExpect(jsonPath("$[?(@.produtoId == '%s')].precoVenda".formatted(promo), contains(24.0)))
                .andExpect(jsonPath("$[?(@.produtoId == '%s')].precoNormal".formatted(promo), contains(30.0)))
                .andExpect(jsonPath("$[?(@.produtoId == '%s')].precoNormal".formatted(vencida),
                        contains(org.hamcrest.Matchers.nullValue())));

        // Vitrine padrão de volta (não interfere em outros testes)
        vitrine("""
                {"secoes":[
                  {"tipo":"SUGESTOES","titulo":"Sugestões da casa","ativa":true,"quantidade":8},
                  {"tipo":"PROMOCOES","titulo":"Promoções","ativa":true,"quantidade":8},
                  {"tipo":"MAIS_PEDIDOS","titulo":"Mais pedidos","ativa":true,"quantidade":6},
                  {"tipo":"NOVIDADES","titulo":"Novidades","ativa":false,"quantidade":6},
                  {"tipo":"MENOS_PEDIDOS","titulo":"Experimente também","ativa":false,"quantidade":6}]}""");
        getAuth("/api/admin/cardapio/vitrine").andExpect(jsonPath("$[*].tipo", not(hasItem("X"))));
    }

    @Test
    void vitrineRejeitaSecaoRepetida() throws Exception {
        mvc.perform(put("/api/admin/cardapio/vitrine").header("Authorization", token)
                        .contentType(MediaType.APPLICATION_JSON).content("""
                                {"secoes":[{"tipo":"PROMOCOES","titulo":"A","ativa":true,"quantidade":3},
                                           {"tipo":"PROMOCOES","titulo":"B","ativa":true,"quantidade":3}]}"""))
                .andExpect(jsonPath("$.codigo").value("SECAO_DUPLICADA"));
        mvc.perform(put("/api/admin/cardapio/vitrine").header("Authorization", token)
                        .contentType(MediaType.APPLICATION_JSON).content("""
                                {"secoes":[{"tipo":"PROMOCOES","titulo":"A","ativa":true,"quantidade":30}]}"""))
                .andExpect(status().isBadRequest());
    }
}
