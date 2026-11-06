package br.com.bar.gestao;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.condition.EnabledIf;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.testcontainers.DockerClientFactory;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.util.List;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Base dos testes de integração: um PostgreSQL real (Testcontainers) compartilhado por todas as
 * classes, com as migrations do Flyway. Sem Docker disponível, os testes são ignorados.
 */
@EnabledIf("br.com.bar.gestao.IntegracaoBase#dockerDisponivel")
@SpringBootTest(properties = {
        "app.security.jwt-secret=segredo-de-teste-de-integracao-com-32-caracteres",
        "app.security.admin-login=admin",
        "app.security.admin-password=senha-de-teste-123",
        "app.upload-dir=build/test-uploads"
})
@AutoConfigureMockMvc
public abstract class IntegracaoBase {

    private static PostgreSQLContainer postgres;

    static boolean dockerDisponivel() {
        try {
            return DockerClientFactory.instance().isDockerAvailable();
        } catch (Throwable e) {
            return false;
        }
    }

    @DynamicPropertySource
    static void banco(DynamicPropertyRegistry registro) {
        synchronized (IntegracaoBase.class) {
            if (postgres == null) {
                postgres = new PostgreSQLContainer("postgres:16-alpine");
                postgres.start();
            }
        }
        registro.add("spring.datasource.url", postgres::getJdbcUrl);
        registro.add("spring.datasource.username", postgres::getUsername);
        registro.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    protected MockMvc mvc;

    protected String token;

    @BeforeEach
    void autenticar() throws Exception {
        String body = mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"login\":\"admin\",\"senha\":\"senha-de-teste-123\"}"))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        token = "Bearer " + JsonPath.read(body, "$.token");
    }

    protected ResultActions postJson(String url, String json) throws Exception {
        return mvc.perform(post(url).header("Authorization", token)
                .contentType(MediaType.APPLICATION_JSON).content(json));
    }

    protected ResultActions getAuth(String url, Object... vars) throws Exception {
        return mvc.perform(get(url, vars).header("Authorization", token));
    }

    protected static String corpo(ResultActions r) throws Exception {
        return r.andReturn().getResponse().getContentAsString();
    }

    protected String idUnidade(String sigla) throws Exception {
        String unidades = corpo(getAuth("/api/admin/unidades"));
        return JsonPath.<List<String>>read(unidades, "$[?(@.sigla == '" + sigla + "')].id").getFirst();
    }

    /** Cria um produto de revenda e devolve o id. {@code embalagensJson} pode ser "[]". */
    protected String criarProduto(String nome, String siglaEstoque, String custo, String embalagensJson) throws Exception {
        String json = """
                {"nome":"%s","tipo":"REVENDA","unidadeEstoqueId":"%s","custoMedio":%s,"precoVenda":10,
                 "estoqueMinimo":0,"embalagens":%s}
                """.formatted(nome, idUnidade(siglaEstoque), custo, embalagensJson);
        return JsonPath.read(corpo(postJson("/api/admin/produtos", json).andExpect(status().isCreated())), "$.id");
    }
}
