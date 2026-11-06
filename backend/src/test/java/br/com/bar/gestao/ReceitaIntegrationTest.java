package br.com.bar.gestao;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Etapa 3 — receitas para consulta, com texto formatado colado de sites. */
class ReceitaIntegrationTest extends IntegracaoBase {

    @Test
    void cadastroConsultaEdicaoEExclusao() throws Exception {
        String nome = "Batata frita " + UUID.randomUUID().toString().substring(0, 8);

        // Conteúdo como chega ao colar de um site: estilos, scripts e links são removidos
        String receita = corpo(postJson("/api/admin/receitas", """
                {"nome":"%s","rendimento":"1 porção","tempoPreparoMin":12,
                 "ingredientes":"<ul style=\\"color:red\\"><li><b>300 g</b> de batata</li><li>20 ml de óleo</li></ul>",
                 "modoPreparo":"<div><b>Aqueça</b> o óleo<script>x()</script></div><div><a href=\\"http://x\\">Frite</a></div>"}
                """.formatted(nome))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.ingredientes").value("<ul><li><b>300 g</b> de batata</li><li>20 ml de óleo</li></ul>"))
                .andExpect(jsonPath("$.modoPreparo").value("<p><b>Aqueça</b> o óleo</p><p>Frite</p>"))
                .andExpect(jsonPath("$.rendimento").value("1 porção")));
        String id = JsonPath.read(receita, "$.id");

        getAuth("/api/admin/receitas?nome={n}", nome.substring(0, 10).toUpperCase())
                .andExpect(jsonPath("$.totalElementos").value(1))
                .andExpect(jsonPath("$.conteudo[0].tempoPreparoMin").value(12));

        // Nome repetido
        postJson("/api/admin/receitas", "{\"nome\":\"%s\"}".formatted(nome.toLowerCase()))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.codigo").value("RECEITA_DUPLICADA"));

        // Edição: campos vazios ficam nulos
        mvc.perform(put("/api/admin/receitas/{id}", id).header("Authorization", token)
                        .contentType("application/json")
                        .content("{\"nome\":\"%s\",\"ingredientes\":\"<p><br></p>\"}".formatted(nome)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ingredientes").doesNotExist())
                .andExpect(jsonPath("$.rendimento").doesNotExist());

        mvc.perform(delete("/api/admin/receitas/{id}", id).header("Authorization", token))
                .andExpect(status().isNoContent());
        getAuth("/api/admin/receitas/{id}", id).andExpect(status().isNotFound());
    }

    @Test
    void nomeEObrigatorio() throws Exception {
        postJson("/api/admin/receitas", "{\"nome\":\"\"}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.campos.nome").exists());
    }
}
