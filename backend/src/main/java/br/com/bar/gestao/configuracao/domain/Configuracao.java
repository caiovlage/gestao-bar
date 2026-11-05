package br.com.bar.gestao.configuracao.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;

import java.time.Instant;

/** Configuração chave/valor. As chaves existentes são criadas pelas migrations. */
@Entity
@Table(name = "configuracao")
public class Configuracao {

    @Id
    @Column(length = 60)
    private String chave;

    @Column(nullable = false, length = 500)
    private String valor;

    @Column(length = 200)
    private String descricao;

    @Column(name = "atualizado_em", nullable = false)
    private Instant atualizadoEm;

    protected Configuracao() {
    }

    @PrePersist
    @PreUpdate
    void tocar() {
        atualizadoEm = Instant.now();
    }

    public String getChave() {
        return chave;
    }

    public String getValor() {
        return valor;
    }

    public String getDescricao() {
        return descricao;
    }

    public void alterarValor(String valor) {
        this.valor = valor;
    }
}
