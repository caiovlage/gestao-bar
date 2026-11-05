package br.com.bar.gestao;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Fluxo completo da Etapa 1 contra um PostgreSQL real (migrations Flyway incluídas).
 * Requer Docker; sem Docker o teste é ignorado.
 */
@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest(properties = {
        "app.security.jwt-secret=segredo-de-teste-de-integracao-com-32-caracteres",
        "app.security.admin-login=admin",
        "app.security.admin-password=senha-de-teste-123",
        "app.upload-dir=build/test-uploads"
})
@AutoConfigureMockMvc
class FundacaoIntegrationTest {

    @Container
    @ServiceConnection
    static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:16-alpine");

    @Autowired
    MockMvc mvc;

    private String token;

    @BeforeEach
    void login() throws Exception {
        String body = mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"login\":\"admin\",\"senha\":\"senha-de-teste-123\"}"))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        token = "Bearer " + JsonPath.read(body, "$.token");
    }

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
        mvc.perform(get("/api/admin/unidades").header("Authorization", token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(7));
        mvc.perform(get("/api/admin/categorias").header("Authorization", token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].nome").value("Bebidas"));
    }

    @Test
    void fluxoCompletoDeCategoriaEProduto() throws Exception {
        String unidades = mvc.perform(get("/api/admin/unidades").header("Authorization", token))
                .andReturn().getResponse().getContentAsString();
        String unId = JsonPath.<java.util.List<String>>read(unidades, "$[?(@.sigla == 'un')].id").getFirst();
        String cxId = JsonPath.<java.util.List<String>>read(unidades, "$[?(@.sigla == 'cx')].id").getFirst();

        String categoria = mvc.perform(post("/api/admin/categorias").header("Authorization", token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"nome\":\"Drinks\",\"ordem\":15}"))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        String categoriaId = JsonPath.read(categoria, "$.id");

        String produto = mvc.perform(post("/api/admin/produtos").header("Authorization", token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"nome":"Cerveja lata","tipo":"REVENDA","categoriaId":"%s","unidadeEstoqueId":"%s",
                                 "custoMedio":3.5,"precoVenda":8,"estoqueMinimo":48,"vendeNoCardapio":true,
                                 "embalagens":[{"unidadeId":"%s","descricao":"Caixa 12","fator":12}]}
                                """.formatted(categoriaId, unId, cxId)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.estoqueAtual").value(0))
                .andExpect(jsonPath("$.abaixoMinimo").value(true))
                .andExpect(jsonPath("$.embalagens[0].fator").value(12))
                .andReturn().getResponse().getContentAsString();
        String produtoId = JsonPath.read(produto, "$.id");

        mvc.perform(get("/api/admin/produtos").param("nome", "cerv").param("categoriaId", categoriaId)
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
    void validacaoDeCamposRetornaErroPadronizado() throws Exception {
        mvc.perform(post("/api/admin/produtos").header("Authorization", token)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"nome\":\"\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("DADOS_INVALIDOS"))
                .andExpect(jsonPath("$.campos.nome").exists());
    }
}
