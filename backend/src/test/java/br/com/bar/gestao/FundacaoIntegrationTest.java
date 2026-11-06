package br.com.bar.gestao;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Fluxo completo da Etapa 1 contra um PostgreSQL real (migrations Flyway incluídas). */
class FundacaoIntegrationTest extends IntegracaoBase {

    @Test
    void rotasAdministrativasExigemToken() throws Exception {
        mvc.perform(get("/api/admin/produtos"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.codigo").value("NAO_AUTENTICADO"));
    }

    @Test
    void loginComSenhaErradaRetorna401() throws Exception {
        mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"login\":\"admin\",\"senha\":\"errada\"}"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void seedsDeUnidadesECategoriasExistem() throws Exception {
        // Verifica presença (não posição): outros testes compartilham o banco e criam registros.
        getAuth("/api/admin/unidades")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.sigla == 'kg')].fatorBase").value(1000.0))
                .andExpect(jsonPath("$[?(@.sigla == 'cx')].grandeza").value("EMBALAGEM"));
        getAuth("/api/admin/categorias")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.nome == 'Bebidas')]").exists())
                .andExpect(jsonPath("$[?(@.nome == 'Ingredientes')].exibirCardapio").value(false));
    }

    @Test
    void fluxoCompletoDeCategoriaEProduto() throws Exception {
        String categoriaId = JsonPath.read(corpo(postJson("/api/admin/categorias", "{\"nome\":\"Drinks\",\"ordem\":15}")
                .andExpect(status().isCreated())), "$.id");

        String produto = corpo(postJson("/api/admin/produtos", """
                {"nome":"Cerveja lata","tipo":"REVENDA","categoriaId":"%s","unidadeEstoqueId":"%s",
                 "custoMedio":3.5,"precoVenda":8,"estoqueMinimo":48,"vendeNoCardapio":true,
                 "embalagens":[{"unidadeId":"%s","descricao":"Caixa 12","fator":12}]}
                """.formatted(categoriaId, idUnidade("un"), idUnidade("cx")))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.estoqueAtual").value(0))
                .andExpect(jsonPath("$.abaixoMinimo").value(true))
                .andExpect(jsonPath("$.embalagens[0].fator").value(12)));
        String produtoId = JsonPath.read(produto, "$.id");

        mvc.perform(get("/api/admin/produtos").param("nome", "cerveja lata").param("categoriaId", categoriaId)
                        .header("Authorization", token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElementos").value(1))
                .andExpect(jsonPath("$.conteudo[0].categoria.nome").value("Drinks"));

        mvc.perform(patch("/api/admin/produtos/{id}/status", produtoId).header("Authorization", token)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"ativo\":false}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ativo").value(false));

        // Categoria com produto vinculado não pode ser excluída
        mvc.perform(delete("/api/admin/categorias/{id}", categoriaId).header("Authorization", token))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.codigo").value("CATEGORIA_EM_USO"));
    }

    @Test
    void buscaPorCodigoDeBarrasOuQrCode() throws Exception {
        String ean = "789" + String.valueOf(System.nanoTime()).substring(0, 10);
        String id = JsonPath.read(corpo(postJson("/api/admin/produtos", """
                {"nome":"Água %s","tipo":"REVENDA","unidadeEstoqueId":"%s","custoMedio":1,"precoVenda":4,
                 "estoqueMinimo":0,"codigoInterno":"%s"}""".formatted(ean, idUnidade("un"), ean))
                .andExpect(status().isCreated())), "$.id");

        getAuth("/api/admin/produtos/por-codigo?codigo={c}", " " + ean + " ")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(id));
        getAuth("/api/admin/produtos/por-codigo?codigo={c}", "000-nao-existe")
                .andExpect(status().isNotFound());

        // QR Code com URL (mais de 30 caracteres e com "/")
        String qr = "https://fornecedor.example/p/" + ean + "?lote=42";
        postJson("/api/admin/produtos", """
                {"nome":"Kit %s","tipo":"REVENDA","unidadeEstoqueId":"%s","custoMedio":1,"precoVenda":4,
                 "estoqueMinimo":0,"codigoInterno":"%s"}""".formatted(ean, idUnidade("un"), qr))
                .andExpect(status().isCreated());
        getAuth("/api/admin/produtos/por-codigo?codigo={c}", qr.toUpperCase())
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.codigoInterno").value(qr));
    }

    @Test
    void validacaoDeCamposRetornaErroPadronizado() throws Exception {
        postJson("/api/admin/produtos", "{\"nome\":\"\"}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("DADOS_INVALIDOS"))
                .andExpect(jsonPath("$.campos.nome").exists());
    }
}
