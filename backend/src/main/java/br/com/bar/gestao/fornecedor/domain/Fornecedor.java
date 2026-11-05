package br.com.bar.gestao.fornecedor.domain;

import br.com.bar.gestao.shared.domain.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;

@Entity
@Table(name = "fornecedor")
public class Fornecedor extends BaseEntity {

    @Column(nullable = false, length = 120)
    private String nome;

    @Column(name = "nome_fantasia", length = 120)
    private String nomeFantasia;

    @Column(length = 14)
    private String cnpj;

    @Column(length = 20)
    private String telefone;

    @Column(length = 120)
    private String email;

    @Column(length = 250)
    private String endereco;

    @Column(length = 1000)
    private String observacoes;

    @Column(nullable = false)
    private boolean ativo = true;

    protected Fornecedor() {
    }

    public Fornecedor(String nome) {
        this.nome = nome;
    }

    public void atualizar(String nome, String nomeFantasia, String cnpj, String telefone, String email,
                          String endereco, String observacoes) {
        this.nome = nome;
        this.nomeFantasia = nomeFantasia;
        this.cnpj = cnpj;
        this.telefone = telefone;
        this.email = email;
        this.endereco = endereco;
        this.observacoes = observacoes;
    }

    public void alterarStatus(boolean ativo) {
        this.ativo = ativo;
    }

    public String getNome() {
        return nome;
    }

    public String getNomeFantasia() {
        return nomeFantasia;
    }

    public String getCnpj() {
        return cnpj;
    }

    public String getTelefone() {
        return telefone;
    }

    public String getEmail() {
        return email;
    }

    public String getEndereco() {
        return endereco;
    }

    public String getObservacoes() {
        return observacoes;
    }

    public boolean isAtivo() {
        return ativo;
    }
}
