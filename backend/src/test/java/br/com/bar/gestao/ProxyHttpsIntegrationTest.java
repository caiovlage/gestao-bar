package br.com.bar.gestao;

import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Painel aberto em https://domínio atrás do Cloudflare + nginx (que fala http com o backend):
 * o login não pode ser recusado como CORS (403).
 */
class ProxyHttpsIntegrationTest extends IntegracaoBase {

    @Test
    void loginPeloDominioHttpsAtrasDoProxy() throws Exception {
        mvc.perform(post("/api/auth/login")
                        .header("Host", "barentrenos.com.br")
                        .header("Origin", "https://barentrenos.com.br")
                        .header("X-Forwarded-Proto", "https")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"login\":\"admin\",\"senha\":\"senha-de-teste-123\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").exists());
    }

    @Test
    void origemDeOutroSiteContinuaBloqueada() throws Exception {
        mvc.perform(post("/api/auth/login")
                        .header("Host", "barentrenos.com.br")
                        .header("Origin", "https://site-malicioso.com")
                        .header("X-Forwarded-Proto", "https")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"login\":\"admin\",\"senha\":\"senha-de-teste-123\"}"))
                .andExpect(status().isForbidden());
    }
}
