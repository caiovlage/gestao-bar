package br.com.bar.gestao.shared.security;

import org.junit.jupiter.api.Test;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JwtServiceTest {

    private static final String SEGREDO = "segredo-de-teste-com-pelo-menos-32-caracteres!!";
    private static final Instant AGORA = Instant.parse("2026-11-05T20:00:00Z");

    private JwtService servico(String segredo, Clock clock) {
        var props = new SecurityProperties(segredo, Duration.ofHours(12), "admin", "senha", List.of());
        return new JwtService(props, clock);
    }

    @Test
    void emiteEValidaToken() {
        JwtService jwt = servico(SEGREDO, Clock.fixed(AGORA, ZoneOffset.UTC));
        var token = jwt.emitir("admin");

        assertThat(token.expiraEm()).isEqualTo(AGORA.plus(Duration.ofHours(12)));
        assertThat(jwt.validar(token.token())).contains("admin");
    }

    @Test
    void rejeitaTokenExpirado() {
        String token = servico(SEGREDO, Clock.fixed(AGORA, ZoneOffset.UTC)).emitir("admin").token();
        JwtService depois = servico(SEGREDO, Clock.fixed(AGORA.plus(Duration.ofHours(13)), ZoneOffset.UTC));

        assertThat(depois.validar(token)).isEmpty();
    }

    @Test
    void rejeitaTokenAssinadoComOutroSegredo() {
        String token = servico("outro-segredo-diferente-com-32-caracteres-ou-mais", Clock.systemUTC())
                .emitir("admin").token();

        assertThat(servico(SEGREDO, Clock.systemUTC()).validar(token)).isEmpty();
    }

    @Test
    void rejeitaTokenMalformado() {
        assertThat(servico(SEGREDO, Clock.systemUTC()).validar("nao-e-um-jwt")).isEmpty();
    }

    @Test
    void exigeSegredoComTamanhoMinimo() {
        assertThatThrownBy(() -> servico("curto", Clock.systemUTC()))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("JWT_SECRET");
    }
}
