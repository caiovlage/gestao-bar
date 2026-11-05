package br.com.bar.gestao.catalogo.domain;

import br.com.bar.gestao.shared.domain.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;

import java.math.BigDecimal;

@Entity
@Table(name = "unidade_medida")
public class UnidadeMedida extends BaseEntity {

    @Column(nullable = false, length = 10)
    private String sigla;

    @Column(nullable = false, length = 40)
    private String nome;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Grandeza grandeza;

    /** Quantas unidades base (g, ml, un) cabem em 1 desta unidade. Nulo para embalagens. */
    @Column(name = "fator_base", precision = 15, scale = 6)
    private BigDecimal fatorBase;

    protected UnidadeMedida() {
    }

    public UnidadeMedida(String sigla, String nome, Grandeza grandeza, BigDecimal fatorBase) {
        this.sigla = sigla;
        this.nome = nome;
        this.grandeza = grandeza;
        this.fatorBase = grandeza == Grandeza.EMBALAGEM ? null : fatorBase;
    }

    public boolean isEmbalagem() {
        return grandeza == Grandeza.EMBALAGEM;
    }

    /** Unidade base da grandeza (g, ml, un): a única permitida como unidade de estoque. */
    public boolean isUnidadeBase() {
        return !isEmbalagem() && fatorBase != null && fatorBase.compareTo(BigDecimal.ONE) == 0;
    }

    public String getSigla() {
        return sigla;
    }

    public String getNome() {
        return nome;
    }

    public Grandeza getGrandeza() {
        return grandeza;
    }

    public BigDecimal getFatorBase() {
        return fatorBase;
    }
}
