package br.com.bar.gestao.pedido.domain;

import br.com.bar.gestao.shared.domain.BaseEntity;
import br.com.bar.gestao.shared.exception.NegocioException;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.UUID;

/**
 * Pedido feito pelo cliente no cardápio digital. Não é venda: só entra no faturamento quando
 * o pagamento presencial é registrado (gerando uma venda vinculada). Preparo e pagamento têm
 * status independentes — ex.: ENTREGUE e PENDENTE = entregue, aguardando pagamento.
 */
@Entity
@Table(name = "pedido")
public class Pedido extends BaseEntity {

    /** Ordem do fluxo de preparo; CANCELADO fica fora do fluxo. */
    public enum StatusPreparo { RECEBIDO, ACEITO, EM_PREPARO, PRONTO, ENTREGUE, CANCELADO }

    public enum StatusFinanceiro { PENDENTE, PAGO, CANCELADO }

    @Column(nullable = false, unique = true)
    private long numero;

    @Column(name = "chave_idempotencia", nullable = false, unique = true)
    private UUID chaveIdempotencia;

    @Column(name = "cliente_nome", nullable = false, length = 80)
    private String clienteNome;

    @Column(nullable = false, length = 80)
    private String local;

    @Column(length = 500)
    private String observacao;

    @Enumerated(EnumType.STRING)
    @Column(name = "status_preparo", nullable = false, length = 15)
    private StatusPreparo statusPreparo = StatusPreparo.RECEBIDO;

    @Enumerated(EnumType.STRING)
    @Column(name = "status_financeiro", nullable = false, length = 10)
    private StatusFinanceiro statusFinanceiro = StatusFinanceiro.PENDENTE;

    @Column(nullable = false, precision = 14, scale = 2)
    private BigDecimal total = BigDecimal.ZERO;

    @Column(name = "estoque_reservado", nullable = false)
    private boolean estoqueReservado;

    @Column(name = "motivo_cancelamento", length = 500)
    private String motivoCancelamento;

    @Column(name = "venda_id", unique = true)
    private UUID vendaId;

    @Column(name = "ip_origem", length = 64)
    private String ipOrigem;

    @Column(name = "aceito_em")
    private Instant aceitoEm;

    @Column(name = "pronto_em")
    private Instant prontoEm;

    @Column(name = "entregue_em")
    private Instant entregueEm;

    @Column(name = "pago_em")
    private Instant pagoEm;

    @Column(name = "cancelado_em")
    private Instant canceladoEm;

    @OneToMany(mappedBy = "pedido", cascade = CascadeType.ALL)
    @OrderBy("ordem")
    private List<PedidoItem> itens = new ArrayList<>();

    protected Pedido() {
    }

    public Pedido(long numero, UUID chaveIdempotencia, String clienteNome, String local, String observacao,
                  String ipOrigem) {
        this.numero = numero;
        this.chaveIdempotencia = chaveIdempotencia;
        this.clienteNome = clienteNome;
        this.local = local;
        this.observacao = observacao;
        this.ipOrigem = ipOrigem;
    }

    public void adicionarItem(UUID produtoId, String produtoNome, int quantidade, BigDecimal precoUnitario,
                              String observacao) {
        PedidoItem item = new PedidoItem(this, itens.size() + 1, produtoId, produtoNome, quantidade, precoUnitario, observacao);
        itens.add(item);
        total = total.add(item.getTotal());
    }

    // ---------------------------------------------------------------- transições

    public void aceitar(boolean reservouEstoque) {
        if (statusPreparo != StatusPreparo.RECEBIDO) {
            throw new NegocioException("STATUS_INVALIDO", "O pedido nº " + numero + " já foi " + rotulo(statusPreparo) + ".");
        }
        this.statusPreparo = StatusPreparo.ACEITO;
        this.estoqueReservado = reservouEstoque;
        this.aceitoEm = Instant.now();
    }

    /** Avança no preparo (EM_PREPARO, PRONTO, ENTREGUE). Só para frente e depois de aceito. */
    public void avancar(StatusPreparo novo) {
        if (novo == StatusPreparo.RECEBIDO || novo == StatusPreparo.ACEITO || novo == StatusPreparo.CANCELADO) {
            throw new NegocioException("STATUS_INVALIDO", "Use as ações de aceitar, recusar ou cancelar.");
        }
        if (statusPreparo == StatusPreparo.CANCELADO) {
            throw new NegocioException("PEDIDO_CANCELADO", "O pedido nº " + numero + " está cancelado.");
        }
        if (statusPreparo == StatusPreparo.RECEBIDO) {
            throw new NegocioException("STATUS_INVALIDO", "Aceite o pedido nº " + numero + " antes de iniciar o preparo.");
        }
        if (novo.ordinal() <= statusPreparo.ordinal()) {
            throw new NegocioException("STATUS_INVALIDO", "O pedido nº " + numero + " já está " + rotulo(statusPreparo) + ".");
        }
        this.statusPreparo = novo;
        Instant agora = Instant.now();
        if (novo == StatusPreparo.PRONTO || novo == StatusPreparo.ENTREGUE) {
            if (prontoEm == null) prontoEm = agora;
        }
        if (novo == StatusPreparo.ENTREGUE) entregueEm = agora;
    }

    /** O pagamento pode ser registrado a partir do aceite (antes ou depois da entrega). */
    public void exigirPagavel() {
        if (statusFinanceiro == StatusFinanceiro.PAGO) {
            throw new NegocioException("PEDIDO_JA_PAGO", "O pagamento do pedido nº " + numero + " já foi registrado.");
        }
        if (statusPreparo == StatusPreparo.CANCELADO) {
            throw new NegocioException("PEDIDO_CANCELADO", "O pedido nº " + numero + " está cancelado.");
        }
        if (statusPreparo == StatusPreparo.RECEBIDO) {
            throw new NegocioException("STATUS_INVALIDO", "Aceite o pedido nº " + numero + " antes de registrar o pagamento.");
        }
    }

    public void marcarPago(UUID vendaId) {
        this.statusFinanceiro = StatusFinanceiro.PAGO;
        this.vendaId = vendaId;
        this.estoqueReservado = false;
        this.pagoEm = Instant.now();
    }

    /** Recusa (antes do aceite) ou cancelamento. Pedido pago não é cancelado aqui: cancele a venda. */
    public void cancelar(String motivo) {
        if (statusPreparo == StatusPreparo.CANCELADO) {
            throw new NegocioException("PEDIDO_CANCELADO", "O pedido nº " + numero + " já está cancelado.");
        }
        if (statusFinanceiro == StatusFinanceiro.PAGO) {
            throw new NegocioException("PEDIDO_JA_PAGO", "O pedido nº " + numero + " já foi pago. Para desfazer, cancele a venda.");
        }
        this.statusPreparo = StatusPreparo.CANCELADO;
        this.statusFinanceiro = StatusFinanceiro.CANCELADO;
        this.estoqueReservado = false;
        this.motivoCancelamento = motivo;
        this.canceladoEm = Instant.now();
    }

    private static String rotulo(StatusPreparo s) {
        return switch (s) {
            case RECEBIDO -> "recebido";
            case ACEITO -> "aceito";
            case EM_PREPARO -> "em preparo";
            case PRONTO -> "pronto";
            case ENTREGUE -> "entregue";
            case CANCELADO -> "cancelado";
        };
    }

    // ---------------------------------------------------------------- getters

    public long getNumero() {
        return numero;
    }

    public UUID getChaveIdempotencia() {
        return chaveIdempotencia;
    }

    public String getClienteNome() {
        return clienteNome;
    }

    public String getLocal() {
        return local;
    }

    public String getObservacao() {
        return observacao;
    }

    public StatusPreparo getStatusPreparo() {
        return statusPreparo;
    }

    public StatusFinanceiro getStatusFinanceiro() {
        return statusFinanceiro;
    }

    public BigDecimal getTotal() {
        return total;
    }

    public boolean isEstoqueReservado() {
        return estoqueReservado;
    }

    public String getMotivoCancelamento() {
        return motivoCancelamento;
    }

    public UUID getVendaId() {
        return vendaId;
    }

    public Instant getAceitoEm() {
        return aceitoEm;
    }

    public Instant getProntoEm() {
        return prontoEm;
    }

    public Instant getEntregueEm() {
        return entregueEm;
    }

    public Instant getPagoEm() {
        return pagoEm;
    }

    public Instant getCanceladoEm() {
        return canceladoEm;
    }

    public List<PedidoItem> getItens() {
        return Collections.unmodifiableList(itens);
    }
}
