package br.com.bar.gestao.venda.domain;

import br.com.bar.gestao.shared.domain.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

import java.math.BigDecimal;
import java.util.UUID;

/** Item vendido com nome, preço e custo congelados no momento da venda. */
@Entity
@Table(name = "venda_item")
public class VendaItem extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "venda_id")
    private Venda venda;

    @Column(nullable = false)
    private int ordem;

    @Column(name = "produto_id", nullable = false)
    private UUID produtoId;

    @Column(name = "produto_nome", nullable = false, length = 120)
    private String produtoNome;

    @Column(nullable = false, precision = 15, scale = 3)
    private BigDecimal quantidade;

    @Column(name = "preco_unitario", nullable = false, precision = 14, scale = 2)
    private BigDecimal precoUnitario;

    @Column(name = "custo_unitario", nullable = false, precision = 18, scale = 6)
    private BigDecimal custoUnitario;

    @Column(nullable = false, precision = 14, scale = 2)
    private BigDecimal total;

    @Column(name = "custo_total", nullable = false, precision = 14, scale = 2)
    private BigDecimal custoTotal;

    /** Se o produto controlava estoque no momento da venda (define o estorno no cancelamento). */
    @Column(name = "controla_estoque", nullable = false)
    private boolean controlaEstoque;

    protected VendaItem() {
    }

    VendaItem(Venda venda, int ordem, UUID produtoId, String produtoNome, BigDecimal quantidade,
              BigDecimal precoUnitario, BigDecimal custoUnitario, BigDecimal total, BigDecimal custoTotal,
              boolean controlaEstoque) {
        this.venda = venda;
        this.ordem = ordem;
        this.produtoId = produtoId;
        this.produtoNome = produtoNome;
        this.quantidade = quantidade;
        this.precoUnitario = precoUnitario;
        this.custoUnitario = custoUnitario;
        this.total = total;
        this.custoTotal = custoTotal;
        this.controlaEstoque = controlaEstoque;
    }

    public int getOrdem() {
        return ordem;
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

    public BigDecimal getCustoUnitario() {
        return custoUnitario;
    }

    public BigDecimal getTotal() {
        return total;
    }

    public BigDecimal getCustoTotal() {
        return custoTotal;
    }

    public boolean isControlaEstoque() {
        return controlaEstoque;
    }
}
