package br.com.bar.gestao.pedido.application;

import br.com.bar.gestao.shared.exception.LimiteExcedidoException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Limite simples de pedidos por IP (janela deslizante, em memória). Protege o cardápio público
 * contra envio em massa sem exigir cadastro do cliente. Uma mesa com várias pessoas no mesmo
 * Wi-Fi compartilha o IP, por isso o limite é generoso.
 */
@Component
public class LimitePedidos {

    private static final int MAX_ORIGENS = 10_000;

    private final int maximo;
    private final Duration janela;
    private final Clock clock;
    private final Map<String, Deque<Instant>> envios = new ConcurrentHashMap<>();

    public LimitePedidos(@Value("${app.pedidos.limite-por-ip:20}") int maximo,
                         @Value("${app.pedidos.janela-limite:PT10M}") Duration janela, Clock clock) {
        this.maximo = maximo;
        this.janela = janela;
        this.clock = clock;
    }

    public void registrar(String origem) {
        if (origem == null || maximo <= 0) return;
        Instant agora = clock.instant();
        Instant limite = agora.minus(janela);
        if (envios.size() > MAX_ORIGENS) {
            envios.values().removeIf(d -> { synchronized (d) { return d.isEmpty() || d.peekLast().isBefore(limite); } });
        }
        Deque<Instant> fila = envios.computeIfAbsent(origem, k -> new ArrayDeque<>());
        synchronized (fila) {
            while (!fila.isEmpty() && fila.peekFirst().isBefore(limite)) fila.pollFirst();
            if (fila.size() >= maximo) {
                throw new LimiteExcedidoException("Muitos pedidos enviados em pouco tempo. Aguarde alguns minutos "
                        + "ou chame um atendente.");
            }
            fila.addLast(agora);
        }
    }
}
