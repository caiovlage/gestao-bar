package br.com.bar.gestao.notificacao.application;

import br.com.bar.gestao.pedido.application.PedidoRecebido;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import java.math.BigDecimal;
import java.text.NumberFormat;
import java.util.Locale;

/** Avisa os aparelhos inscritos quando um pedido do cardápio é gravado (depois do commit, em segundo plano). */
@Component
public class AvisoNovoPedido {

    private final NotificacaoService notificacoes;

    public AvisoNovoPedido(NotificacaoService notificacoes) {
        this.notificacoes = notificacoes;
    }

    @Async
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void aoReceber(PedidoRecebido e) {
        String total = NumberFormat.getCurrencyInstance(Locale.forLanguageTag("pt-BR")).format(
                e.total() == null ? BigDecimal.ZERO : e.total());
        notificacoes.enviarParaTodos(new NotificacaoService.Mensagem(
                "Novo pedido nº " + e.numero() + " · " + e.local(),
                e.clienteNome() + " · " + e.itens() + (e.itens() == 1 ? " item" : " itens") + " · " + total,
                "/admin/pedidos",
                "pedido-" + e.numero()));
    }
}
