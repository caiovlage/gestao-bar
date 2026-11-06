package br.com.bar.gestao.caixa.domain;

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

/** Suprimento (entrada de dinheiro, ex.: troco) ou retirada (sangria). Imutável. */
@Entity
@Immutable
@Table(name = "movimentacao_caixa")
public class MovimentacaoCaixa {

    public enum Tipo { SUPRIMENTO, RETIRADA }

    @Id
    private UUID id;

    @Column(name = "caixa_id", nullable = false)
    private UUID caixaId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 12)
    private Tipo tipo;

    @Column(nullable = false, precision = 14, scale = 2)
    private BigDecimal valor;

    @Column(nullable = false, length = 300)
    private String motivo;

    @Column(name = "data_hora", nullable = false)
    private Instant dataHora;

    protected MovimentacaoCaixa() {
    }

    public MovimentacaoCaixa(UUID caixaId, Tipo tipo, BigDecimal valor, String motivo) {
        this.id = UUID.randomUUID();
        this.caixaId = caixaId;
        this.tipo = tipo;
        this.valor = valor;
        this.motivo = motivo;
        this.dataHora = Instant.now();
    }

    public UUID getId() {
        return id;
    }

    public UUID getCaixaId() {
        return caixaId;
    }

    public Tipo getTipo() {
        return tipo;
    }

    public BigDecimal getValor() {
        return valor;
    }

    public String getMotivo() {
        return motivo;
    }

    public Instant getDataHora() {
        return dataHora;
    }
}
