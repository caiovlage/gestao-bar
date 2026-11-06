package br.com.bar.gestao.despesa.domain;

import br.com.bar.gestao.shared.domain.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

/** Despesa operacional (água, luz, aluguel...), usada no cálculo do lucro líquido. */
@Entity
@Table(name = "despesa")
public class Despesa extends BaseEntity {

    public enum Categoria { AGUA, LUZ, GAS, ALUGUEL, MANUTENCAO, LIMPEZA, FUNCIONARIOS, IMPOSTOS, OUTROS }

    @Column(nullable = false, length = 200)
    private String descricao;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Categoria categoria;

    @Column(nullable = false, precision = 14, scale = 2)
    private BigDecimal valor;

    @Column(nullable = false)
    private LocalDate data;

    @Column(name = "fornecedor_id")
    private UUID fornecedorId;

    @Column(length = 500)
    private String observacao;

    protected Despesa() {
    }

    public Despesa(String descricao) {
        this.descricao = descricao;
    }

    public void atualizar(String descricao, Categoria categoria, BigDecimal valor, LocalDate data, UUID fornecedorId,
                          String observacao) {
        this.descricao = descricao;
        this.categoria = categoria;
        this.valor = valor;
        this.data = data;
        this.fornecedorId = fornecedorId;
        this.observacao = observacao;
    }

    public String getDescricao() {
        return descricao;
    }

    public Categoria getCategoria() {
        return categoria;
    }

    public BigDecimal getValor() {
        return valor;
    }

    public LocalDate getData() {
        return data;
    }

    public UUID getFornecedorId() {
        return fornecedorId;
    }

    public String getObservacao() {
        return observacao;
    }
}
