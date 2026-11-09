package br.com.bar.gestao.comanda.domain;

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
import java.util.Optional;
import java.util.UUID;

/**
 * Comanda (conta aberta): o cliente vai consumindo e paga no fim. Não é venda: só entra no
 * faturamento quando é fechada (gerando uma venda vinculada).
 */
@Entity
@Table(name = "comanda")
public class Comanda extends BaseEntity {

    public enum Status { ABERTA, FECHADA, CANCELADA }

    @Column(nullable = false, unique = true)
    private long numero;

    /** Caixa em que a comanda foi aberta; ele só fecha depois das comandas. */
    @Column(name = "caixa_id", nullable = false)
    private UUID caixaId;

    @Column(name = "cliente_nome", nullable = false, length = 80)
    private String clienteNome;

    @Column(length = 80)
    private String local;

    @Column(length = 500)
    private String observacao;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private Status status = Status.ABERTA;

    @Column(nullable = false, precision = 14, scale = 2)
    private BigDecimal total = BigDecimal.ZERO;

    @Column(name = "venda_id", unique = true)
    private UUID vendaId;

    @Column(name = "motivo_cancelamento", length = 500)
    private String motivoCancelamento;

    @Column(name = "fechada_em")
    private Instant fechadaEm;

    @Column(name = "cancelada_em")
    private Instant canceladaEm;

    @OneToMany(mappedBy = "comanda", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("criadoEm")
    private List<ComandaItem> itens = new ArrayList<>();

    protected Comanda() {
    }

    public Comanda(long numero, UUID caixaId, String clienteNome, String local, String observacao) {
        this.numero = numero;
        this.caixaId = caixaId;
        this.clienteNome = clienteNome;
        this.local = local;
        this.observacao = observacao;
    }

    public void exigirAberta() {
        if (status != Status.ABERTA) {
            throw new NegocioException("COMANDA_NAO_ABERTA", "A comanda nº " + numero + " já está "
                    + (status == Status.FECHADA ? "fechada." : "cancelada."));
        }
    }

    /** Lança um item; o mesmo produto com o mesmo preço e observação soma na linha existente. */
    public ComandaItem lancar(UUID produtoId, String produtoNome, BigDecimal quantidade, BigDecimal preco,
                              String observacao, boolean controlaEstoque) {
        exigirAberta();
        Optional<ComandaItem> igual = itens.stream().filter(i -> i.mesmoLancamento(produtoId, preco, observacao)).findFirst();
        ComandaItem item;
        if (igual.isPresent()) {
            item = igual.get();
            item.definirQuantidade(item.getQuantidade().add(quantidade));
        } else {
            item = new ComandaItem(this, produtoId, produtoNome, quantidade, preco, observacao, controlaEstoque);
            itens.add(item);
        }
        recalcular();
        return item;
    }

    /** Retira {@code quantidade} do item (ou o item inteiro, se nula ou maior/igual ao lançado). Devolve o retirado. */
    public BigDecimal retirar(UUID itemId, BigDecimal quantidade) {
        exigirAberta();
        ComandaItem item = item(itemId);
        BigDecimal retirada = quantidade == null || quantidade.compareTo(item.getQuantidade()) >= 0
                ? item.getQuantidade() : quantidade;
        if (retirada.compareTo(item.getQuantidade()) == 0) {
            itens.remove(item);
        } else {
            item.definirQuantidade(item.getQuantidade().subtract(retirada));
        }
        recalcular();
        return retirada;
    }

    public ComandaItem item(UUID itemId) {
        return itens.stream().filter(i -> i.getId().equals(itemId)).findFirst()
                .orElseThrow(() -> new NegocioException("ITEM_INVALIDO", "Item não encontrado nesta comanda."));
    }

    public void fechar(UUID vendaId) {
        exigirAberta();
        this.status = Status.FECHADA;
        this.vendaId = vendaId;
        this.fechadaEm = Instant.now();
    }

    public void cancelar(String motivo) {
        exigirAberta();
        this.status = Status.CANCELADA;
        this.motivoCancelamento = motivo;
        this.canceladaEm = Instant.now();
    }

    public void alterarIdentificacao(String clienteNome, String local, String observacao) {
        exigirAberta();
        this.clienteNome = clienteNome;
        this.local = local;
        this.observacao = observacao;
    }

    private void recalcular() {
        total = itens.stream().map(ComandaItem::getTotal).reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    public long getNumero() {
        return numero;
    }

    public UUID getCaixaId() {
        return caixaId;
    }

    public String getClienteNome() {
        return clienteNome;
    }

    public String getLocal() {
        return local;
    }

    public String getObservacao() {
        return observacao;
    }

    public Status getStatus() {
        return status;
    }

    public BigDecimal getTotal() {
        return total;
    }

    public UUID getVendaId() {
        return vendaId;
    }

    public String getMotivoCancelamento() {
        return motivoCancelamento;
    }

    public Instant getFechadaEm() {
        return fechadaEm;
    }

    public Instant getCanceladaEm() {
        return canceladaEm;
    }

    public List<ComandaItem> getItens() {
        return Collections.unmodifiableList(itens);
    }
}
