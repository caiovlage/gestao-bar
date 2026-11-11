package br.com.bar.gestao.notificacao.application;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.security.Signature;

import static org.assertj.core.api.Assertions.assertThat;

class WebPushCriptoTest {

    /** Vetor de teste da RFC 8291, Apêndice A. */
    @Test
    void cifraIgualAoExemploDaRfc8291() throws Exception {
        byte[] mensagem = "When I grow up, I want to be a watermelon".getBytes(StandardCharsets.UTF_8);
        byte[] asPrivada = WebPushCripto.b64d("yfWPiYE-n46HLnH0KqZOF1fJJU3MYrct3AELtAQ-oRw");
        byte[] asPublica = WebPushCripto.b64d(
                "BP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27mlmlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A8");
        byte[] uaPublica = WebPushCripto.b64d(
                "BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcxaOzi6-AYWXvTBHm4bjyPjs7Vd8pZGH6SRpkNtoIAiw4");
        byte[] auth = WebPushCripto.b64d("BTBZMqHH6r4Tts7J_aSIgg");
        byte[] salt = WebPushCripto.b64d("DGv6ra1nlYgDCS1FRnbzlw");

        byte[] corpo = WebPushCripto.cifrar(mensagem, uaPublica, auth, WebPushCripto.chavePrivada(asPrivada),
                asPublica, salt);

        assertThat(WebPushCripto.b64(corpo)).isEqualTo(
                "DGv6ra1nlYgDCS1FRnbzlwAAEABBBP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27mlmlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEq"
                        + "KK6PBru3jl7A_yl95bQpu6cVPTpK4Mqgkf1CXztLVBSt2Ks3oZwbuwXPXLWyouBWLVWGNWQexSgSxsj_Qulcy4a-fN");
    }

    @Test
    void jwtVapidAssinadoComAChaveGerada() throws Exception {
        String[] chaves = WebPushCripto.gerarChavesVapid();
        assertThat(WebPushCripto.b64d(chaves[0])).hasSize(65);
        assertThat(WebPushCripto.b64d(chaves[1])).hasSize(32);

        String auth = WebPushCripto.autorizacaoVapid("https://fcm.googleapis.com/fcm/send/abc",
                "mailto:contato@barentrenos.com.br", chaves[0], chaves[1], 1_700_000_000L);
        assertThat(auth).startsWith("vapid t=").endsWith(", k=" + chaves[0]);

        String jwt = auth.substring("vapid t=".length(), auth.indexOf(','));
        String[] partes = jwt.split("\\.");
        String claims = new String(WebPushCripto.b64d(partes[1]), StandardCharsets.UTF_8);
        assertThat(claims).contains("\"aud\":\"https://fcm.googleapis.com\"").contains("\"exp\":1700043200");

        Signature s = Signature.getInstance("SHA256withECDSAinP1363Format");
        s.initVerify(WebPushCripto.chavePublica(WebPushCripto.b64d(chaves[0])));
        s.update((partes[0] + "." + partes[1]).getBytes(StandardCharsets.US_ASCII));
        assertThat(s.verify(WebPushCripto.b64d(partes[2]))).isTrue();
    }
}
