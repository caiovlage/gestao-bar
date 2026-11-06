package br.com.bar.gestao.estoque.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Saldo de estoque de um produto, na unidade de estoque do produto.
 * Alterado exclusivamente pelo EstoqueService, sempre com movimentação registrada (Etapa 2).
 */
@Entity
@Table(name = "estoque")
public class Estoque {

    @Id
    @Column(name = "produto_id")
    private UUID produtoId;

    @Column(nullable = false, precision = 15, scale = 3)
    private BigDecimal quantidade = BigDecimal.ZERO;

    @Column(name = "quantidade_reservada", nullable = false, precision = 15, scale = 3)
    private BigDecimal quantidadeReservada = BigDecimal.ZERO;

    @Version
    private Long version;

    @Column(name = "atualizado_em", nullable = false)
    private Instant atualizadoEm;

    protected Estoque() {
    }

    public Estoque(UUID produtoId) {
        this.produtoId = produtoId;
    }

    @PrePersist
    @PreUpdate
    void tocar() {
        atualizadoEm = Instant.now();
    }

    public UUID getProdutoId() {
        return produtoId;
    }

    public BigDecimal getQuantidade() {
        return quantidade;
    }

    public BigDecimal getQuantidadeReservada() {
        return quantidadeReservada;
    }

    public BigDecimal getDisponivel() {
        return quantidade.subtract(quantidadeReservada);
    }

    /** Soma (ou subtrai, se negativo) do saldo. Use somente via EstoqueService, com movimentação. */
    public void aplicar(BigDecimal delta) {
        this.quantidade = this.quantidade.add(delta);
    }
}
