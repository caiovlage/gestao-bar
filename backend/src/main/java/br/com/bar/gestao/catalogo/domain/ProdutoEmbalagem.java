package br.com.bar.gestao.catalogo.domain;

import br.com.bar.gestao.shared.domain.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

import java.math.BigDecimal;

/**
 * Embalagem de compra de um produto. Ex.: "Caixa 12" (cx) → fator 12 (un);
 * "Pacote 2 kg" (pct) → fator 2000 (g). O fator é sempre expresso na unidade de estoque do produto.
 */
@Entity
@Table(name = "produto_embalagem")
public class ProdutoEmbalagem extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "produto_id")
    private Produto produto;

    @ManyToOne(fetch = FetchType.EAGER, optional = false)
    @JoinColumn(name = "unidade_id")
    private UnidadeMedida unidade;

    @Column(nullable = false, length = 60)
    private String descricao;

    @Column(nullable = false, precision = 15, scale = 3)
    private BigDecimal fator;

    protected ProdutoEmbalagem() {
    }

    ProdutoEmbalagem(Produto produto, UnidadeMedida unidade, String descricao, BigDecimal fator) {
        this.produto = produto;
        atualizar(unidade, descricao, fator);
    }

    void atualizar(UnidadeMedida unidade, String descricao, BigDecimal fator) {
        this.unidade = unidade;
        this.descricao = descricao;
        this.fator = fator;
    }

    public Produto getProduto() {
        return produto;
    }

    public UnidadeMedida getUnidade() {
        return unidade;
    }

    public String getDescricao() {
        return descricao;
    }

    public BigDecimal getFator() {
        return fator;
    }
}
