package br.com.bar.gestao.compra.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import org.hibernate.annotations.Immutable;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/** Preço de aquisição de um recebimento (por unidade de estoque) e o efeito no custo médio. Imutável. */
@Entity
@Immutable
@Table(name = "historico_custo")
public class HistoricoCusto {

    @Id
    private UUID id;

    @Column(name = "produto_id", nullable = false)
    private UUID produtoId;

    @Column(name = "fornecedor_id")
    private UUID fornecedorId;

    @Column(name = "compra_id", nullable = false)
    private UUID compraId;

    @Column(name = "data_hora", nullable = false)
    private Instant dataHora;

    @Column(nullable = false, precision = 15, scale = 3)
    private BigDecimal quantidade;

    @Column(name = "custo_unitario", nullable = false, precision = 18, scale = 6)
    private BigDecimal custoUnitario;

    @Column(name = "custo_medio_anterior", nullable = false, precision = 18, scale = 6)
    private BigDecimal custoMedioAnterior;

    @Column(name = "custo_medio_novo", nullable = false, precision = 18, scale = 6)
    private BigDecimal custoMedioNovo;

    protected HistoricoCusto() {
    }

    public HistoricoCusto(UUID produtoId, UUID fornecedorId, UUID compraId, BigDecimal quantidade,
                          BigDecimal custoUnitario, BigDecimal custoMedioAnterior, BigDecimal custoMedioNovo) {
        this.id = UUID.randomUUID();
        this.produtoId = produtoId;
        this.fornecedorId = fornecedorId;
        this.compraId = compraId;
        this.dataHora = Instant.now();
        this.quantidade = quantidade;
        this.custoUnitario = custoUnitario;
        this.custoMedioAnterior = custoMedioAnterior;
        this.custoMedioNovo = custoMedioNovo;
    }
}
