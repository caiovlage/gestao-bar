package br.com.bar.gestao.shared.security;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.time.Duration;
import java.util.List;

/**
 * Configurações de segurança, todas vindas de variáveis de ambiente (ver .env.example).
 * Nenhuma credencial possui valor padrão no código.
 */
@ConfigurationProperties("app.security")
public record SecurityProperties(
        String jwtSecret,
        Duration jwtExpiration,
        String adminLogin,
        String adminPassword,
        List<String> corsAllowedOrigins) {

    public SecurityProperties {
        if (jwtExpiration == null) {
            jwtExpiration = Duration.ofHours(12);
        }
        if (corsAllowedOrigins == null) {
            corsAllowedOrigins = List.of();
        }
    }
}
