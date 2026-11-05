package br.com.bar.gestao.catalogo.domain;

import br.com.bar.gestao.shared.domain.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;

@Entity
@Table(name = "categoria")
public class Categoria extends BaseEntity {

    @Column(nullable = false, length = 60)
    private String nome;

    @Column(nullable = false)
    private int ordem;

    @Column(name = "exibir_cardapio", nullable = false)
    private boolean exibirCardapio = true;

    @Column(nullable = false)
    private boolean ativo = true;

    protected Categoria() {
    }

    public Categoria(String nome, int ordem, boolean exibirCardapio) {
        atualizar(nome, ordem, exibirCardapio);
    }

    public void atualizar(String nome, int ordem, boolean exibirCardapio) {
        this.nome = nome;
        this.ordem = ordem;
        this.exibirCardapio = exibirCardapio;
    }

    public void alterarStatus(boolean ativo) {
        this.ativo = ativo;
    }

    public String getNome() {
        return nome;
    }

    public int getOrdem() {
        return ordem;
    }

    public boolean isExibirCardapio() {
        return exibirCardapio;
    }

    public boolean isAtivo() {
        return ativo;
    }
}
