package br.com.bar.gestao.compra.domain;

import br.com.bar.gestao.shared.domain.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.UUID;

/**
 * Item de compra. Guarda a unidade de compra como cópia (ex.: "Caixa 12") e a quantidade convertida
 * para a unidade de estoque, para não depender de embalagens que podem mudar no cadastro.
 */
@Entity
@Table(name = "compra_item")
public class CompraItem extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "compra_id")
    private Compra compra;

    @Column(nullable = false)
    private int ordem;

    @Column(name = "produto_id", nullable = false)
    private UUID produtoId;

    @Column(name = "produto_nome", nullable = false, length = 120)
    private String produtoNome;

    @Column(nullable = false, precision = 15, scale = 3)
    private BigDecimal quantidade;

    @Column(name = "unidade_id")
    private UUID unidadeId;

    @Column(name = "embalagem_id")
    private UUID embalagemId;

    @Column(name = "unidade_compra", nullable = false, length = 80)
    private String unidadeCompra;

    @Column(name = "quantidade_estoque", nullable = false, precision = 15, scale = 3)
    private BigDecimal quantidadeEstoque;

    /** Preço por unidade de compra (ex.: por caixa). */
    @Column(name = "custo_unitario", nullable = false, precision = 14, scale = 4)
    private BigDecimal custoUnitario;

    @Column(name = "custo_total", nullable = false, precision = 14, scale = 2)
    private BigDecimal custoTotal;

    protected CompraItem() {
    }

    CompraItem(Compra compra, int ordem, Dados d) {
        this.compra = compra;
        this.ordem = ordem;
        this.produtoId = d.produtoId();
        this.produtoNome = d.produtoNome();
        this.quantidade = d.quantidade();
        this.unidadeId = d.unidadeId();
        this.embalagemId = d.embalagemId();
        this.unidadeCompra = d.unidadeCompra();
        this.quantidadeEstoque = d.quantidadeEstoque();
        this.custoUnitario = d.custoUnitario();
        this.custoTotal = d.quantidade().multiply(d.custoUnitario()).setScale(2, RoundingMode.HALF_UP);
    }

    public record Dados(UUID produtoId, String produtoNome, BigDecimal quantidade, UUID unidadeId, UUID embalagemId,
                        String unidadeCompra, BigDecimal quantidadeEstoque, BigDecimal custoUnitario) {
    }

    /** Custo por unidade de estoque (ex.: preço da caixa ÷ 12), usado no custo médio. */
    public BigDecimal custoUnitarioEstoque() {
        return quantidade.multiply(custoUnitario).divide(quantidadeEstoque, 6, RoundingMode.HALF_UP);
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

    public UUID getUnidadeId() {
        return unidadeId;
    }

    public UUID getEmbalagemId() {
        return embalagemId;
    }

    public String getUnidadeCompra() {
        return unidadeCompra;
    }

    public BigDecimal getQuantidadeEstoque() {
        return quantidadeEstoque;
    }

    public BigDecimal getCustoUnitario() {
        return custoUnitario;
    }

    public BigDecimal getCustoTotal() {
        return custoTotal;
    }
}
