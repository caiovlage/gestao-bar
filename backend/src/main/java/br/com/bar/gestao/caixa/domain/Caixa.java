package br.com.bar.gestao.caixa.domain;

import br.com.bar.gestao.shared.domain.BaseEntity;
import br.com.bar.gestao.shared.exception.NegocioException;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * Sessão de caixa (um turno). Enquanto aberta, recebe vendas e suprimentos/retiradas;
 * no fechamento, os totais são calculados e congelados junto com o valor contado.
 */
@Entity
@Table(name = "caixa")
public class Caixa extends BaseEntity {

    public enum Status { ABERTO, FECHADO }

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private Status status = Status.ABERTO;

    @Column(name = "aberto_em", nullable = false)
    private Instant abertoEm;

    @Column(name = "saldo_inicial", nullable = false, precision = 14, scale = 2)
    private BigDecimal saldoInicial;

    @Column(name = "observacao_abertura", length = 500)
    private String observacaoAbertura;

    @Column(name = "fechado_em")
    private Instant fechadoEm;

    @Column(name = "total_vendas", precision = 14, scale = 2)
    private BigDecimal totalVendas;

    @Column(name = "quantidade_vendas")
    private Integer quantidadeVendas;

    @Column(name = "total_dinheiro", precision = 14, scale = 2)
    private BigDecimal totalDinheiro;

    @Column(name = "total_pix", precision = 14, scale = 2)
    private BigDecimal totalPix;

    @Column(name = "total_cartao_debito", precision = 14, scale = 2)
    private BigDecimal totalCartaoDebito;

    @Column(name = "total_cartao_credito", precision = 14, scale = 2)
    private BigDecimal totalCartaoCredito;

    @Column(name = "total_outros", precision = 14, scale = 2)
    private BigDecimal totalOutros;

    @Column(name = "total_suprimentos", precision = 14, scale = 2)
    private BigDecimal totalSuprimentos;

    @Column(name = "total_retiradas", precision = 14, scale = 2)
    private BigDecimal totalRetiradas;

    @Column(name = "saldo_esperado", precision = 14, scale = 2)
    private BigDecimal saldoEsperado;

    @Column(name = "saldo_contado", precision = 14, scale = 2)
    private BigDecimal saldoContado;

    @Column(precision = 14, scale = 2)
    private BigDecimal diferenca;

    @Column(name = "observacao_fechamento", length = 500)
    private String observacaoFechamento;

    protected Caixa() {
    }

    public Caixa(BigDecimal saldoInicial, String observacao) {
        this.abertoEm = Instant.now();
        this.saldoInicial = saldoInicial;
        this.observacaoAbertura = observacao;
    }

    public boolean isAberto() {
        return status == Status.ABERTO;
    }

    public void exigirAberto() {
        if (!isAberto()) {
            throw new NegocioException("CAIXA_FECHADO", "Este caixa já foi fechado.");
        }
    }

    /** Fecha o caixa congelando os totais apurados e o valor contado em dinheiro. */
    public void fechar(Totais t, BigDecimal saldoContado, String observacao) {
        exigirAberto();
        this.status = Status.FECHADO;
        this.fechadoEm = Instant.now();
        this.quantidadeVendas = t.quantidadeVendas();
        this.totalVendas = t.totalVendas();
        this.totalDinheiro = t.dinheiro();
        this.totalPix = t.pix();
        this.totalCartaoDebito = t.cartaoDebito();
        this.totalCartaoCredito = t.cartaoCredito();
        this.totalOutros = t.outros();
        this.totalSuprimentos = t.suprimentos();
        this.totalRetiradas = t.retiradas();
        this.saldoEsperado = t.saldoEsperado();
        this.saldoContado = saldoContado;
        this.diferenca = saldoContado.subtract(t.saldoEsperado());
        this.observacaoFechamento = observacao;
    }

    /** Totais congelados no fechamento (só para caixas fechados). */
    public Totais totaisCongelados() {
        return new Totais(quantidadeVendas, totalVendas, totalDinheiro, totalPix, totalCartaoDebito,
                totalCartaoCredito, totalOutros, totalSuprimentos, totalRetiradas, saldoEsperado);
    }

    /**
     * Totais do caixa. {@code saldoEsperado} é o dinheiro que deve estar na gaveta:
     * saldo inicial + vendas em dinheiro + suprimentos − retiradas.
     */
    public record Totais(int quantidadeVendas, BigDecimal totalVendas, BigDecimal dinheiro, BigDecimal pix,
                         BigDecimal cartaoDebito, BigDecimal cartaoCredito, BigDecimal outros,
                         BigDecimal suprimentos, BigDecimal retiradas, BigDecimal saldoEsperado) {
    }

    public Status getStatus() {
        return status;
    }

    public Instant getAbertoEm() {
        return abertoEm;
    }

    public BigDecimal getSaldoInicial() {
        return saldoInicial;
    }

    public String getObservacaoAbertura() {
        return observacaoAbertura;
    }

    public Instant getFechadoEm() {
        return fechadoEm;
    }

    public BigDecimal getSaldoContado() {
        return saldoContado;
    }

    public BigDecimal getDiferenca() {
        return diferenca;
    }

    public String getObservacaoFechamento() {
        return observacaoFechamento;
    }
}
