package br.com.bar.gestao.estoque.domain;

import br.com.bar.gestao.shared.domain.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "inventario_item")
public class InventarioItem extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "inventario_id")
    private Inventario inventario;

    @Column(name = "produto_id", nullable = false)
    private UUID produtoId;

    /** Quantidade física contada; nula = ainda não contado (ignorado na conclusão). */
    @Column(name = "quantidade_contada", precision = 15, scale = 3)
    private BigDecimal quantidadeContada;

    @Column(name = "quantidade_sistema", precision = 15, scale = 3)
    private BigDecimal quantidadeSistema;

    @Column(precision = 15, scale = 3)
    private BigDecimal diferenca;

    @Column(name = "movimentacao_id")
    private UUID movimentacaoId;

    protected InventarioItem() {
    }

    InventarioItem(Inventario inventario, UUID produtoId) {
        this.inventario = inventario;
        this.produtoId = produtoId;
    }

    public void registrarContagem(BigDecimal quantidadeContada) {
        this.quantidadeContada = quantidadeContada;
    }

    public void registrarResultado(BigDecimal quantidadeSistema, BigDecimal diferenca, UUID movimentacaoId) {
        this.quantidadeSistema = quantidadeSistema;
        this.diferenca = diferenca;
        this.movimentacaoId = movimentacaoId;
    }

    public boolean isContado() {
        return quantidadeContada != null;
    }

    public UUID getProdutoId() {
        return produtoId;
    }

    public BigDecimal getQuantidadeContada() {
        return quantidadeContada;
    }

    public BigDecimal getQuantidadeSistema() {
        return quantidadeSistema;
    }

    public BigDecimal getDiferenca() {
        return diferenca;
    }

    public UUID getMovimentacaoId() {
        return movimentacaoId;
    }
}
