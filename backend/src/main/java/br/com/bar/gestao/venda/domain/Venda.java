package br.com.bar.gestao.venda.domain;

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

/** Venda registrada no PDV. Nunca é excluída: o cancelamento mantém o registro e estorna o estoque. */
@Entity
@Table(name = "venda")
public class Venda extends BaseEntity {

    public enum Status { CONCLUIDA, CANCELADA }

    @Column(nullable = false, unique = true)
    private long numero;

    @Column(name = "chave_idempotencia", nullable = false, unique = true)
    private UUID chaveIdempotencia;

    @Column(name = "caixa_id", nullable = false)
    private UUID caixaId;

    /** Pedido do cardápio digital que originou a venda (no máximo uma venda por pedido). */
    @Column(name = "pedido_id", unique = true)
    private UUID pedidoId;

    @Column(name = "data_hora", nullable = false)
    private Instant dataHora;

    @Column(nullable = false, precision = 14, scale = 2)
    private BigDecimal subtotal;

    @Column(nullable = false, precision = 14, scale = 2)
    private BigDecimal desconto;

    @Column(nullable = false, precision = 14, scale = 2)
    private BigDecimal total;

    @Column(name = "custo_total", nullable = false, precision = 14, scale = 2)
    private BigDecimal custoTotal;

    @Column(name = "lucro_bruto", nullable = false, precision = 14, scale = 2)
    private BigDecimal lucroBruto;

    @Enumerated(EnumType.STRING)
    @Column(name = "forma_pagamento", nullable = false, length = 20)
    private FormaPagamento formaPagamento;

    @Column(name = "valor_recebido", precision = 14, scale = 2)
    private BigDecimal valorRecebido;

    @Column(precision = 14, scale = 2)
    private BigDecimal troco;

    @Column(length = 500)
    private String observacao;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 12)
    private Status status = Status.CONCLUIDA;

    @Column(name = "motivo_cancelamento", length = 500)
    private String motivoCancelamento;

    @Column(name = "cancelada_em")
    private Instant canceladaEm;

    @OneToMany(mappedBy = "venda", cascade = CascadeType.ALL)
    @OrderBy("ordem")
    private List<VendaItem> itens = new ArrayList<>();

    protected Venda() {
    }

    public Venda(long numero, UUID chaveIdempotencia, UUID caixaId, FormaPagamento formaPagamento, String observacao) {
        this.numero = numero;
        this.chaveIdempotencia = chaveIdempotencia;
        this.caixaId = caixaId;
        this.formaPagamento = formaPagamento;
        this.observacao = observacao;
        this.dataHora = Instant.now();
    }

    public void adicionarItem(UUID produtoId, String produtoNome, BigDecimal quantidade, BigDecimal precoUnitario,
                              BigDecimal custoUnitario, BigDecimal total, BigDecimal custoTotal, boolean controlaEstoque) {
        itens.add(new VendaItem(this, itens.size() + 1, produtoId, produtoNome, quantidade, precoUnitario,
                custoUnitario, total, custoTotal, controlaEstoque));
    }

    public void vincularPedido(UUID pedidoId) {
        this.pedidoId = pedidoId;
    }

    public UUID getPedidoId() {
        return pedidoId;
    }

    public void definirValores(BigDecimal subtotal, BigDecimal desconto, BigDecimal custoTotal,
                               BigDecimal valorRecebido, BigDecimal troco) {
        this.subtotal = subtotal;
        this.desconto = desconto;
        this.total = subtotal.subtract(desconto);
        this.custoTotal = custoTotal;
        this.lucroBruto = this.total.subtract(custoTotal);
        this.valorRecebido = valorRecebido;
        this.troco = troco;
    }

    public void cancelar(String motivo) {
        if (status == Status.CANCELADA) {
            throw new NegocioException("VENDA_JA_CANCELADA", "A venda nº " + numero + " já está cancelada.");
        }
        this.status = Status.CANCELADA;
        this.motivoCancelamento = motivo;
        this.canceladaEm = Instant.now();
    }

    public long getNumero() {
        return numero;
    }

    public UUID getChaveIdempotencia() {
        return chaveIdempotencia;
    }

    public UUID getCaixaId() {
        return caixaId;
    }

    public Instant getDataHora() {
        return dataHora;
    }

    public BigDecimal getSubtotal() {
        return subtotal;
    }

    public BigDecimal getDesconto() {
        return desconto;
    }

    public BigDecimal getTotal() {
        return total;
    }

    public BigDecimal getCustoTotal() {
        return custoTotal;
    }

    public BigDecimal getLucroBruto() {
        return lucroBruto;
    }

    public FormaPagamento getFormaPagamento() {
        return formaPagamento;
    }

    public BigDecimal getValorRecebido() {
        return valorRecebido;
    }

    public BigDecimal getTroco() {
        return troco;
    }

    public String getObservacao() {
        return observacao;
    }

    public Status getStatus() {
        return status;
    }

    public String getMotivoCancelamento() {
        return motivoCancelamento;
    }

    public Instant getCanceladaEm() {
        return canceladaEm;
    }

    public List<VendaItem> getItens() {
        return Collections.unmodifiableList(itens);
    }
}
