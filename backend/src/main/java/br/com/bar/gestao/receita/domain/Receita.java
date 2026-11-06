package br.com.bar.gestao.receita.domain;

import br.com.bar.gestao.shared.domain.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;

/** Receita para consulta na cozinha. Ingredientes e modo de preparo são HTML já limpo. */
@Entity
@Table(name = "receita")
public class Receita extends BaseEntity {

    @Column(nullable = false, length = 120)
    private String nome;

    @Column(name = "foto_url", length = 300)
    private String fotoUrl;

    @Column(length = 60)
    private String rendimento;

    @Column(name = "tempo_preparo_min")
    private Integer tempoPreparoMin;

    @Column(columnDefinition = "text")
    private String ingredientes;

    @Column(name = "modo_preparo", columnDefinition = "text")
    private String modoPreparo;

    protected Receita() {
    }

    public Receita(String nome) {
        this.nome = nome;
    }

    public void atualizar(String nome, String rendimento, Integer tempoPreparoMin, String ingredientes,
                          String modoPreparo) {
        this.nome = nome;
        this.rendimento = rendimento;
        this.tempoPreparoMin = tempoPreparoMin;
        this.ingredientes = ingredientes;
        this.modoPreparo = modoPreparo;
    }

    public void definirFoto(String fotoUrl) {
        this.fotoUrl = fotoUrl;
    }

    public String getNome() {
        return nome;
    }

    public String getFotoUrl() {
        return fotoUrl;
    }

    public String getRendimento() {
        return rendimento;
    }

    public Integer getTempoPreparoMin() {
        return tempoPreparoMin;
    }

    public String getIngredientes() {
        return ingredientes;
    }

    public String getModoPreparo() {
        return modoPreparo;
    }
}
