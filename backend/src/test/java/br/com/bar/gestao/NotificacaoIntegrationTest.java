package br.com.bar.gestao;

import br.com.bar.gestao.notificacao.application.WebPushCripto;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;

import java.util.Base64;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.not;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Notificações push: chave VAPID estável e cadastro/remoção de aparelhos. */
class NotificacaoIntegrationTest extends IntegracaoBase {

    @Test
    void inscricaoDeAparelhos() throws Exception {
        String chave = JsonPath.read(corpo(getAuth("/api/admin/notificacoes/chave-publica").andExpect(status().isOk())),
                "$.chavePublica");
        assertThat(Base64.getUrlDecoder().decode(chave)).hasSize(65);
        // mesma chave nas próximas consultas (gerada uma vez e guardada)
        getAuth("/api/admin/notificacoes/chave-publica").andExpect(jsonPath("$.chavePublica").value(chave));

        String p256dh = WebPushCripto.gerarChavesVapid()[0];
        String auth = Base64.getUrlEncoder().withoutPadding().encodeToString(new byte[16]);
        String endpoint = "https://fcm.googleapis.com/fcm/send/" + UUID.randomUUID();

        // só serviços de push conhecidos (o servidor não envia para endereços quaisquer)
        postJson("/api/admin/notificacoes/inscricoes", """
                {"endpoint":"https://exemplo.com/x","keys":{"p256dh":"%s","auth":"%s"}}""".formatted(p256dh, auth))
                .andExpect(jsonPath("$.codigo").value("INSCRICAO_INVALIDA"));
        postJson("/api/admin/notificacoes/inscricoes", """
                {"endpoint":"%s","keys":{"p256dh":"curta","auth":"%s"}}""".formatted(endpoint, auth))
                .andExpect(jsonPath("$.codigo").value("INSCRICAO_INVALIDA"));

        postJson("/api/admin/notificacoes/inscricoes", """
                {"endpoint":"%s","keys":{"p256dh":"%s","auth":"%s"},"dispositivo":"Celular do Caio"}"""
                .formatted(endpoint, p256dh, auth))
                .andExpect(status().isNoContent());
        // reinscrever o mesmo aparelho não duplica
        postJson("/api/admin/notificacoes/inscricoes", """
                {"endpoint":"%s","keys":{"p256dh":"%s","auth":"%s"},"dispositivo":"Celular do Caio"}"""
                .formatted(endpoint, p256dh, auth))
                .andExpect(status().isNoContent());
        String lista = corpo(getAuth("/api/admin/notificacoes/inscricoes").andExpect(status().isOk()));
        assertThat(JsonPath.<java.util.List<String>>read(lista, "$[?(@.endpoint == '%s')].dispositivo"
                .formatted(endpoint))).containsExactly("Celular do Caio");

        postJson("/api/admin/notificacoes/inscricoes/remover", "{\"endpoint\":\"%s\"}".formatted(endpoint))
                .andExpect(status().isNoContent());
        getAuth("/api/admin/notificacoes/inscricoes").andExpect(jsonPath("$[*].endpoint", not(hasItem(endpoint))));
    }
}
