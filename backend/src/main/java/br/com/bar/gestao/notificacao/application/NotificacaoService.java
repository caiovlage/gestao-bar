package br.com.bar.gestao.notificacao.application;

import br.com.bar.gestao.shared.exception.NegocioException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Notificações Web Push para os aparelhos que aceitaram receber (painel do bar).
 * As chaves VAPID são geradas na primeira vez e guardadas no banco.
 */
@Service
public class NotificacaoService {

    private static final Logger log = LoggerFactory.getLogger(NotificacaoService.class);
    /** Serviços de push conhecidos (evita usar o servidor para requisições a endereços arbitrários). */
    private static final List<String> SERVICOS_PUSH = List.of(
            "fcm.googleapis.com", "updates.push.services.mozilla.com", "push.services.mozilla.com",
            "web.push.apple.com", "notify.windows.com", "push.api.chrome.google.com");

    private final JdbcClient jdbc;
    private final String contato;
    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();
    private volatile String[] chaves;

    public NotificacaoService(JdbcClient jdbc,
                              @Value("${app.push.contato:mailto:contato@barentrenos.com.br}") String contato) {
        this.jdbc = jdbc;
        this.contato = contato;
    }

    public record Inscricao(UUID id, String endpoint, String dispositivo, String usuario, Instant criadoEm,
                            Instant ultimoEnvio, int falhas) {
    }

    /** Mensagem exibida pelo service worker do painel. */
    public record Mensagem(String titulo, String corpo, String url, String tag) {

        String json() {
            return "{\"titulo\":" + js(titulo) + ",\"corpo\":" + js(corpo) + ",\"url\":" + js(url)
                    + ",\"tag\":" + js(tag) + "}";
        }

        private static String js(String s) {
            if (s == null) return "null";
            StringBuilder b = new StringBuilder("\"");
            for (char c : s.toCharArray()) {
                switch (c) {
                    case '"' -> b.append("\\\"");
                    case '\\' -> b.append("\\\\");
                    case '\n' -> b.append("\\n");
                    case '\r' -> b.append("\\r");
                    case '\t' -> b.append("\\t");
                    default -> {
                        if (c < 0x20) b.append(String.format("\\u%04x", (int) c));
                        else b.append(c);
                    }
                }
            }
            return b.append('"').toString();
        }
    }

    // ---------------------------------------------------------------- chaves

    @Transactional
    public String chavePublica() {
        return chaves()[0];
    }

    private String[] chaves() {
        String[] c = chaves;
        if (c != null) return c;
        synchronized (this) {
            if (chaves != null) return chaves;
            var existente = jdbc.sql("SELECT chave_publica, chave_privada FROM push_vapid WHERE id = 1")
                    .query((rs, n) -> new String[] {rs.getString(1), rs.getString(2)}).optional();
            if (existente.isPresent()) {
                chaves = existente.get();
            } else {
                String[] novas = WebPushCripto.gerarChavesVapid();
                jdbc.sql("INSERT INTO push_vapid (id, chave_publica, chave_privada) VALUES (1, :pub, :priv) "
                                + "ON CONFLICT (id) DO NOTHING")
                        .param("pub", novas[0]).param("priv", novas[1]).update();
                chaves = jdbc.sql("SELECT chave_publica, chave_privada FROM push_vapid WHERE id = 1")
                        .query((rs, n) -> new String[] {rs.getString(1), rs.getString(2)}).single();
                log.info("Chaves VAPID geradas para notificações push");
            }
            return chaves;
        }
    }

    // ---------------------------------------------------------------- inscrições

    @Transactional
    public void inscrever(String endpoint, String p256dh, String auth, String dispositivo, String usuario) {
        validarEndpoint(endpoint);
        try {
            if (WebPushCripto.b64d(p256dh).length != 65 || WebPushCripto.b64d(auth).length != 16) {
                throw new IllegalArgumentException();
            }
        } catch (IllegalArgumentException e) {
            throw new NegocioException("INSCRICAO_INVALIDA", "Chaves da inscrição de notificação inválidas.");
        }
        jdbc.sql("""
                        INSERT INTO push_inscricao (id, endpoint, p256dh, auth, dispositivo, usuario)
                        VALUES (:id, :endpoint, :p256dh, :auth, :dispositivo, :usuario)
                        ON CONFLICT (endpoint) DO UPDATE SET p256dh = EXCLUDED.p256dh, auth = EXCLUDED.auth,
                            dispositivo = EXCLUDED.dispositivo, usuario = EXCLUDED.usuario, falhas = 0
                        """)
                .param("id", UUID.randomUUID()).param("endpoint", endpoint).param("p256dh", p256dh)
                .param("auth", auth).param("dispositivo", corta(dispositivo, 120)).param("usuario", corta(usuario, 60))
                .update();
        log.info("Aparelho inscrito para notificações: {}", dispositivo);
    }

    @Transactional
    public void remover(String endpoint) {
        jdbc.sql("DELETE FROM push_inscricao WHERE endpoint = :e").param("e", endpoint).update();
    }

    @Transactional
    public void removerPorId(UUID id) {
        jdbc.sql("DELETE FROM push_inscricao WHERE id = :id").param("id", id).update();
    }

    @Transactional(readOnly = true)
    public List<Inscricao> inscricoes() {
        return jdbc.sql("""
                        SELECT id, endpoint, dispositivo, usuario, criado_em, ultimo_envio, falhas
                        FROM push_inscricao ORDER BY criado_em
                        """)
                .query((rs, n) -> new Inscricao(rs.getObject("id", UUID.class), rs.getString("endpoint"),
                        rs.getString("dispositivo"), rs.getString("usuario"),
                        rs.getObject("criado_em", java.time.OffsetDateTime.class).toInstant(),
                        rs.getObject("ultimo_envio", java.time.OffsetDateTime.class) == null ? null
                                : rs.getObject("ultimo_envio", java.time.OffsetDateTime.class).toInstant(),
                        rs.getInt("falhas")))
                .list();
    }

    // ---------------------------------------------------------------- envio

    /** Envia para todos os aparelhos inscritos. Devolve quantos receberam. */
    public int enviarParaTodos(Mensagem mensagem) {
        record Destino(UUID id, String endpoint, String p256dh, String auth) {
        }
        List<Destino> destinos = jdbc.sql("SELECT id, endpoint, p256dh, auth FROM push_inscricao")
                .query((rs, n) -> new Destino(rs.getObject("id", UUID.class), rs.getString("endpoint"),
                        rs.getString("p256dh"), rs.getString("auth")))
                .list();
        if (destinos.isEmpty()) return 0;
        String[] c = chaves();
        byte[] json = mensagem.json().getBytes(StandardCharsets.UTF_8);
        int entregues = 0;
        for (Destino d : destinos) {
            try {
                HttpRequest req = HttpRequest.newBuilder(URI.create(d.endpoint()))
                        .timeout(Duration.ofSeconds(15))
                        .header("TTL", "3600")
                        .header("Urgency", "high")
                        .header("Content-Encoding", "aes128gcm")
                        .header("Content-Type", "application/octet-stream")
                        .header("Authorization", WebPushCripto.autorizacaoVapid(d.endpoint(), contato, c[0], c[1],
                                Instant.now().getEpochSecond()))
                        .POST(HttpRequest.BodyPublishers.ofByteArray(WebPushCripto.cifrar(json, d.p256dh(), d.auth())))
                        .build();
                int status = http.send(req, HttpResponse.BodyHandlers.discarding()).statusCode();
                if (status >= 200 && status < 300) {
                    entregues++;
                    jdbc.sql("UPDATE push_inscricao SET ultimo_envio = now(), falhas = 0 WHERE id = :id")
                            .param("id", d.id()).update();
                } else if (status == 404 || status == 410) {
                    // inscrição expirada ou cancelada no aparelho
                    jdbc.sql("DELETE FROM push_inscricao WHERE id = :id").param("id", d.id()).update();
                    log.info("Inscrição de push expirada removida ({})", status);
                } else {
                    registrarFalha(d.id(), "HTTP " + status);
                }
            } catch (Exception e) {
                registrarFalha(d.id(), e.getClass().getSimpleName() + ": " + e.getMessage());
                if (e instanceof InterruptedException) Thread.currentThread().interrupt();
            }
        }
        log.info("Notificação \"{}\" enviada para {}/{} aparelho(s)", mensagem.titulo(), entregues, destinos.size());
        return entregues;
    }

    private void registrarFalha(UUID id, String motivo) {
        log.warn("Falha ao enviar notificação push: {}", motivo);
        // muitas falhas seguidas: o aparelho provavelmente não existe mais
        jdbc.sql("UPDATE push_inscricao SET falhas = falhas + 1 WHERE id = :id").param("id", id).update();
        jdbc.sql("DELETE FROM push_inscricao WHERE id = :id AND falhas >= 20").param("id", id).update();
    }

    private static void validarEndpoint(String endpoint) {
        try {
            URI uri = URI.create(endpoint);
            String host = uri.getHost() == null ? "" : uri.getHost().toLowerCase();
            boolean conhecido = SERVICOS_PUSH.stream().anyMatch(s -> host.equals(s) || host.endsWith("." + s));
            if (!"https".equals(uri.getScheme()) || !conhecido) throw new IllegalArgumentException();
        } catch (IllegalArgumentException e) {
            throw new NegocioException("INSCRICAO_INVALIDA", "Serviço de notificação do navegador não reconhecido.");
        }
    }

    private static String corta(String s, int max) {
        if (s == null || s.isBlank()) return null;
        s = s.trim();
        return s.length() > max ? s.substring(0, max) : s;
    }
}
