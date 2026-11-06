package br.com.bar.gestao.compra.domain;

import br.com.bar.gestao.shared.domain.BaseEntity;
import br.com.bar.gestao.shared.exception.NegocioException;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.UUID;

/**
 * Compra. Enquanto RASCUNHO funciona como lista de compras editável (exportável em PDF/Excel);
 * ao ser RECEBIDA, a mercadoria entra no estoque e os custos dos produtos são atualizados.
 */
@Entity
@Table(name = "compra")
public class Compra extends BaseEntity {

    public enum Status { RASCUNHO, RECEBIDA, CANCELADA }

    @Column(nullable = false, unique = true)
    private long numero;

    @Column(name = "fornecedor_id")
    private UUID fornecedorId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 12)
    private Status status = Status.RASCUNHO;

    @Column(length = 500)
    private String observacao;

    @Column(nullable = false, precision = 14, scale = 2)
    private BigDecimal total = BigDecimal.ZERO;

    @Column(name = "recebida_em")
    private Instant recebidaEm;

    @Column(name = "cancelada_em")
    private Instant canceladaEm;

    @OneToMany(mappedBy = "compra", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("ordem")
    private List<CompraItem> itens = new ArrayList<>();

    protected Compra() {
    }

    public Compra(long numero) {
        this.numero = numero;
    }

    public void exigirRascunho() {
        if (status != Status.RASCUNHO) {
            throw new NegocioException("COMPRA_ENCERRADA", "A compra nº " + numero + " já foi "
                    + (status == Status.RECEBIDA ? "recebida" : "cancelada") + " e não pode ser alterada.");
        }
    }

    public void atualizar(UUID fornecedorId, String observacao, List<CompraItem.Dados> itens) {
        exigirRascunho();
        this.fornecedorId = fornecedorId;
        this.observacao = observacao;
        this.itens.clear();
        for (CompraItem.Dados d : itens) {
            this.itens.add(new CompraItem(this, this.itens.size() + 1, d));
        }
        this.total = this.itens.stream().map(CompraItem::getCustoTotal).reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    public void receber() {
        exigirRascunho();
        if (itens.isEmpty()) {
            throw new NegocioException("COMPRA_VAZIA", "Adicione itens antes de registrar o recebimento.");
        }
        this.status = Status.RECEBIDA;
        this.recebidaEm = Instant.now();
    }

    public void cancelar() {
        exigirRascunho();
        this.status = Status.CANCELADA;
        this.canceladaEm = Instant.now();
    }

    public long getNumero() {
        return numero;
    }

    public UUID getFornecedorId() {
        return fornecedorId;
    }

    public Status getStatus() {
        return status;
    }

    public String getObservacao() {
        return observacao;
    }

    public BigDecimal getTotal() {
        return total;
    }

    public Instant getRecebidaEm() {
        return recebidaEm;
    }

    public Instant getCanceladaEm() {
        return canceladaEm;
    }

    public List<CompraItem> getItens() {
        return Collections.unmodifiableList(itens);
    }
}
