package br.com.bar.gestao.estoque.domain;

import br.com.bar.gestao.shared.domain.BaseEntity;
import br.com.bar.gestao.shared.exception.NegocioException;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.OneToMany;
import jakarta.persistence.Table;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.UUID;

/**
 * Contagem física do estoque. Enquanto ABERTO, as contagens podem ser salvas aos poucos;
 * ao concluir, cada item contado gera um ajuste (diferença entre o contado e o saldo do
 * sistema naquele instante).
 */
@Entity
@Table(name = "inventario")
public class Inventario extends BaseEntity {

    public enum Status { ABERTO, CONCLUIDO, CANCELADO }

    @Column(nullable = false, length = 120)
    private String descricao;

    @Column(name = "categoria_id")
    private UUID categoriaId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Status status = Status.ABERTO;

    @Column(length = 500)
    private String observacao;

    @Column(name = "concluido_em")
    private Instant concluidoEm;

    @Column(name = "cancelado_em")
    private Instant canceladoEm;

    @OneToMany(mappedBy = "inventario", cascade = CascadeType.ALL)
    private List<InventarioItem> itens = new ArrayList<>();

    protected Inventario() {
    }

    public Inventario(String descricao, UUID categoriaId, List<UUID> produtoIds) {
        this.descricao = descricao;
        this.categoriaId = categoriaId;
        produtoIds.forEach(id -> itens.add(new InventarioItem(this, id)));
    }

    public void exigirAberto() {
        if (status != Status.ABERTO) {
            throw new NegocioException("INVENTARIO_ENCERRADO", "Este inventário já foi " + status.name().toLowerCase() + ".");
        }
    }

    public void concluir(String observacao) {
        exigirAberto();
        this.status = Status.CONCLUIDO;
        this.observacao = observacao;
        this.concluidoEm = Instant.now();
    }

    public void cancelar(String observacao) {
        exigirAberto();
        this.status = Status.CANCELADO;
        this.observacao = observacao;
        this.canceladoEm = Instant.now();
    }

    public String getDescricao() {
        return descricao;
    }

    public UUID getCategoriaId() {
        return categoriaId;
    }

    public Status getStatus() {
        return status;
    }

    public String getObservacao() {
        return observacao;
    }

    public Instant getConcluidoEm() {
        return concluidoEm;
    }

    public Instant getCanceladoEm() {
        return canceladoEm;
    }

    public List<InventarioItem> getItens() {
        return Collections.unmodifiableList(itens);
    }
}
