package br.com.bar.gestao.shared.security;

import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.Optional;

/** Emissão e validação de tokens JWT (HS256). */
@Service
public class JwtService {

    private static final int TAMANHO_MINIMO_SEGREDO = 32;
    private static final String EMISSOR = "gestao-bar";

    private final SecretKey chave;
    private final Duration expiracao;
    private final Clock clock;

    public JwtService(SecurityProperties props, Clock clock) {
        String segredo = props.jwtSecret();
        if (segredo == null || segredo.getBytes(StandardCharsets.UTF_8).length < TAMANHO_MINIMO_SEGREDO) {
            throw new IllegalStateException(
                    "JWT_SECRET não configurado ou muito curto (mínimo " + TAMANHO_MINIMO_SEGREDO + " caracteres).");
        }
        this.chave = Keys.hmacShaKeyFor(segredo.getBytes(StandardCharsets.UTF_8));
        this.expiracao = props.jwtExpiration();
        this.clock = clock;
    }

    public TokenEmitido emitir(String login) {
        Instant agora = clock.instant();
        Instant expiraEm = agora.plus(expiracao);
        String token = Jwts.builder()
                .issuer(EMISSOR)
                .subject(login)
                .issuedAt(Date.from(agora))
                .expiration(Date.from(expiraEm))
                .signWith(chave)
                .compact();
        return new TokenEmitido(token, expiraEm);
    }

    /** Retorna o login do token, ou vazio se o token for inválido/expirado. */
    public Optional<String> validar(String token) {
        try {
            String login = Jwts.parser()
                    .verifyWith(chave)
                    .requireIssuer(EMISSOR)
                    .clock(() -> Date.from(clock.instant()))
                    .build()
                    .parseSignedClaims(token)
                    .getPayload()
                    .getSubject();
            return Optional.ofNullable(login);
        } catch (JwtException | IllegalArgumentException e) {
            return Optional.empty();
        }
    }

    public record TokenEmitido(String token, Instant expiraEm) {
    }
}
