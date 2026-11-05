package br.com.bar.gestao.catalogo.domain;

import br.com.bar.gestao.shared.domain.BaseEntity;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

@Entity
@Table(name = "produto")
public class Produto extends BaseEntity {

    @Column(nullable = false, length = 120)
    private String nome;

    @Column(length = 1000)
    private String descricao;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "categoria_id")
    private Categoria categoria;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private TipoProduto tipo;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "unidade_estoque_id")
    private UnidadeMedida unidadeEstoque;

    /** Custo de aquisição por unidade de estoque. */
    @Column(name = "custo_medio", nullable = false, precision = 18, scale = 6)
    private BigDecimal custoMedio = BigDecimal.ZERO;

    @Column(name = "preco_venda", precision = 14, scale = 2)
    private BigDecimal precoVenda;

    @Column(name = "estoque_minimo", nullable = false, precision = 15, scale = 3)
    private BigDecimal estoqueMinimo = BigDecimal.ZERO;

    /** Referência por id: fornecedor pertence a outro módulo. */
    @Column(name = "fornecedor_principal_id")
    private UUID fornecedorPrincipalId;

    @Column(name = "codigo_interno", length = 30)
    private String codigoInterno;

    @Column(name = "imagem_url", length = 300)
    private String imagemUrl;

    @Column(name = "vende_no_cardapio", nullable = false)
    private boolean vendeNoCardapio;

    @Column(nullable = false)
    private boolean ativo = true;

    @OneToMany(mappedBy = "produto", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("descricao")
    private List<ProdutoEmbalagem> embalagens = new ArrayList<>();

    protected Produto() {
    }

    public Produto(String nome, TipoProduto tipo, UnidadeMedida unidadeEstoque) {
        this.nome = nome;
        this.tipo = tipo;
        this.unidadeEstoque = unidadeEstoque;
    }

    public void atualizarDados(String nome, String descricao, Categoria categoria, TipoProduto tipo,
                               UnidadeMedida unidadeEstoque, BigDecimal custoMedio, BigDecimal precoVenda,
                               BigDecimal estoqueMinimo, UUID fornecedorPrincipalId, String codigoInterno,
                               boolean vendeNoCardapio) {
        this.nome = nome;
        this.descricao = descricao;
        this.categoria = categoria;
        this.tipo = tipo;
        this.unidadeEstoque = unidadeEstoque;
        this.custoMedio = custoMedio;
        this.precoVenda = precoVenda;
        this.estoqueMinimo = estoqueMinimo;
        this.fornecedorPrincipalId = fornecedorPrincipalId;
        this.codigoInterno = codigoInterno;
        this.vendeNoCardapio = vendeNoCardapio;
    }

    /**
     * Sincroniza as embalagens: itens com id existente são atualizados, itens sem id são criados
     * e os que não vierem na lista são removidos.
     */
    public void sincronizarEmbalagens(List<DadosEmbalagem> dados) {
        Set<UUID> idsMantidos = dados.stream().map(DadosEmbalagem::id)
                .filter(id -> id != null).collect(Collectors.toSet());
        embalagens.removeIf(e -> !idsMantidos.contains(e.getId()));
        Map<UUID, ProdutoEmbalagem> existentes = embalagens.stream()
                .collect(Collectors.toMap(ProdutoEmbalagem::getId, e -> e));
        for (DadosEmbalagem d : dados) {
            ProdutoEmbalagem existente = d.id() == null ? null : existentes.get(d.id());
            if (existente != null) {
                existente.atualizar(d.unidade(), d.descricao(), d.fator());
            } else {
                embalagens.add(new ProdutoEmbalagem(this, d.unidade(), d.descricao(), d.fator()));
            }
        }
    }

    public Optional<ProdutoEmbalagem> embalagem(UUID embalagemId) {
        return embalagens.stream().filter(e -> e.getId().equals(embalagemId)).findFirst();
    }

    /** Margem bruta percentual sobre o preço de venda; vazio se não houver preço. */
    public Optional<BigDecimal> margemBrutaPercentual() {
        if (precoVenda == null || precoVenda.signum() <= 0) {
            return Optional.empty();
        }
        return Optional.of(precoVenda.subtract(custoMedio)
                .multiply(BigDecimal.valueOf(100))
                .divide(precoVenda, 2, RoundingMode.HALF_UP));
    }

    public void alterarStatus(boolean ativo) {
        this.ativo = ativo;
    }

    public void definirImagem(String imagemUrl) {
        this.imagemUrl = imagemUrl;
    }

    public String getNome() {
        return nome;
    }

    public String getDescricao() {
        return descricao;
    }

    public Categoria getCategoria() {
        return categoria;
    }

    public TipoProduto getTipo() {
        return tipo;
    }

    public UnidadeMedida getUnidadeEstoque() {
        return unidadeEstoque;
    }

    public BigDecimal getCustoMedio() {
        return custoMedio;
    }

    public BigDecimal getPrecoVenda() {
        return precoVenda;
    }

    public BigDecimal getEstoqueMinimo() {
        return estoqueMinimo;
    }

    public UUID getFornecedorPrincipalId() {
        return fornecedorPrincipalId;
    }

    public String getCodigoInterno() {
        return codigoInterno;
    }

    public String getImagemUrl() {
        return imagemUrl;
    }

    public boolean isVendeNoCardapio() {
        return vendeNoCardapio;
    }

    public boolean isAtivo() {
        return ativo;
    }

    public List<ProdutoEmbalagem> getEmbalagens() {
        return Collections.unmodifiableList(embalagens);
    }

    public record DadosEmbalagem(UUID id, UnidadeMedida unidade, String descricao, BigDecimal fator) {
    }
}
