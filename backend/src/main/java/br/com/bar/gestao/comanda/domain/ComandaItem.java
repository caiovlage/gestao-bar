package br.com.bar.gestao.comanda.domain;

import br.com.bar.gestao.shared.domain.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.UUID;

/** Item lançado na comanda, com o preço do momento do lançamento. */
@Entity
@Table(name = "comanda_item")
public class ComandaItem extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "comanda_id")
    private Comanda comanda;

    @Column(name = "produto_id", nullable = false)
    private UUID produtoId;

    @Column(name = "produto_nome", nullable = false, length = 120)
    private String produtoNome;

    @Column(nullable = false, precision = 15, scale = 3)
    private BigDecimal quantidade;

    @Column(name = "preco_unitario", nullable = false, precision = 14, scale = 2)
    private BigDecimal precoUnitario;

    @Column(nullable = false, precision = 14, scale = 2)
    private BigDecimal total;

    @Column(length = 200)
    private String observacao;

    @Column(name = "controla_estoque", nullable = false)
    private boolean controlaEstoque;

    protected ComandaItem() {
    }

    ComandaItem(Comanda comanda, UUID produtoId, String produtoNome, BigDecimal quantidade, BigDecimal precoUnitario,
                String observacao, boolean controlaEstoque) {
        this.comanda = comanda;
        this.produtoId = produtoId;
        this.produtoNome = produtoNome;
        this.precoUnitario = precoUnitario;
        this.observacao = observacao;
        this.controlaEstoque = controlaEstoque;
        definirQuantidade(quantidade);
    }

    /** Mesmo produto, preço e observação: o lançamento soma nesta linha. */
    boolean mesmoLancamento(UUID produtoId, BigDecimal preco, String observacao) {
        return this.produtoId.equals(produtoId) && this.precoUnitario.compareTo(preco) == 0
                && java.util.Objects.equals(this.observacao, observacao);
    }

    void definirQuantidade(BigDecimal quantidade) {
        this.quantidade = quantidade;
        this.total = precoUnitario.multiply(quantidade).setScale(2, RoundingMode.HALF_UP);
    }

    public UUID getProdutoId() {
        return produtoId;
    }

    public String getProdutoNome() {
        return produtoNome;
    }

    public BigDecimal getQuantidade() {
        return quantidade;
    }

    public BigDecimal getPrecoUnitario() {
        return precoUnitario;
    }

    public BigDecimal getTotal() {
        return total;
    }

    public String getObservacao() {
        return observacao;
    }

    public boolean isControlaEstoque() {
        return controlaEstoque;
    }

    /** Momento do primeiro lançamento desta linha. */
    public Instant getLancadoEm() {
        return getCriadoEm();
    }
}
