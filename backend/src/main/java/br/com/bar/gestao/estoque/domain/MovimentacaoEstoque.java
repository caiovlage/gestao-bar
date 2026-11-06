package br.com.bar.gestao.estoque.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import org.hibernate.annotations.Immutable;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/** Registro imutável de uma alteração de saldo. Nunca é alterado nem excluído (auditoria). */
@Entity
@Immutable
@Table(name = "movimentacao_estoque")
public class MovimentacaoEstoque {

    @Id
    private UUID id;

    @Column(name = "produto_id", nullable = false)
    private UUID produtoId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private TipoMovimentacao tipo;

    @Column(nullable = false, precision = 15, scale = 3)
    private BigDecimal quantidade;

    @Column(name = "saldo_anterior", nullable = false, precision = 15, scale = 3)
    private BigDecimal saldoAnterior;

    @Column(name = "saldo_posterior", nullable = false, precision = 15, scale = 3)
    private BigDecimal saldoPosterior;

    @Column(name = "custo_unitario", nullable = false, precision = 18, scale = 6)
    private BigDecimal custoUnitario;

    @Column(name = "quantidade_informada", length = 80)
    private String quantidadeInformada;

    @Enumerated(EnumType.STRING)
    @Column(name = "origem_tipo", nullable = false, length = 30)
    private OrigemMovimentacao origem;

    @Column(name = "origem_id")
    private UUID origemId;

    @Column(length = 500)
    private String observacao;

    @Column(name = "data_hora", nullable = false)
    private Instant dataHora;

    protected MovimentacaoEstoque() {
    }

    public MovimentacaoEstoque(UUID produtoId, TipoMovimentacao tipo, BigDecimal quantidade, BigDecimal saldoAnterior,
                               BigDecimal custoUnitario, String quantidadeInformada, OrigemMovimentacao origem,
                               UUID origemId, String observacao) {
        this.id = UUID.randomUUID();
        this.produtoId = produtoId;
        this.tipo = tipo;
        this.quantidade = quantidade;
        this.saldoAnterior = saldoAnterior;
        this.saldoPosterior = saldoAnterior.add(quantidade);
        this.custoUnitario = custoUnitario == null ? BigDecimal.ZERO : custoUnitario;
        this.quantidadeInformada = quantidadeInformada;
        this.origem = origem;
        this.origemId = origemId;
        this.observacao = observacao;
        this.dataHora = Instant.now();
    }

    public UUID getId() {
        return id;
    }

    public UUID getProdutoId() {
        return produtoId;
    }

    public TipoMovimentacao getTipo() {
        return tipo;
    }

    public BigDecimal getQuantidade() {
        return quantidade;
    }

    public BigDecimal getSaldoAnterior() {
        return saldoAnterior;
    }

    public BigDecimal getSaldoPosterior() {
        return saldoPosterior;
    }

    public BigDecimal getCustoUnitario() {
        return custoUnitario;
    }

    public String getQuantidadeInformada() {
        return quantidadeInformada;
    }

    public OrigemMovimentacao getOrigem() {
        return origem;
    }

    public UUID getOrigemId() {
        return origemId;
    }

    public String getObservacao() {
        return observacao;
    }

    public Instant getDataHora() {
        return dataHora;
    }
}
