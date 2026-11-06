package br.com.bar.gestao.pedido.domain;

import br.com.bar.gestao.shared.domain.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

import java.math.BigDecimal;
import java.util.UUID;

/** Item do pedido com o preço que o cliente viu no cardápio. */
@Entity
@Table(name = "pedido_item")
public class PedidoItem extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "pedido_id")
    private Pedido pedido;

    @Column(nullable = false)
    private int ordem;

    @Column(name = "produto_id", nullable = false)
    private UUID produtoId;

    @Column(name = "produto_nome", nullable = false, length = 120)
    private String produtoNome;

    @Column(nullable = false)
    private int quantidade;

    @Column(name = "preco_unitario", nullable = false, precision = 14, scale = 2)
    private BigDecimal precoUnitario;

    @Column(nullable = false, precision = 14, scale = 2)
    private BigDecimal total;

    @Column(length = 200)
    private String observacao;

    protected PedidoItem() {
    }

    PedidoItem(Pedido pedido, int ordem, UUID produtoId, String produtoNome, int quantidade, BigDecimal precoUnitario,
               String observacao) {
        this.pedido = pedido;
        this.ordem = ordem;
        this.produtoId = produtoId;
        this.produtoNome = produtoNome;
        this.quantidade = quantidade;
        this.precoUnitario = precoUnitario;
        this.total = precoUnitario.multiply(BigDecimal.valueOf(quantidade));
        this.observacao = observacao;
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

    public int getQuantidade() {
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
}
