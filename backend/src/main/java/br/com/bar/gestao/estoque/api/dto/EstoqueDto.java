package br.com.bar.gestao.estoque.api.dto;

import br.com.bar.gestao.estoque.domain.OrigemMovimentacao;
import br.com.bar.gestao.estoque.domain.TipoMovimentacao;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public final class EstoqueDto {

    private EstoqueDto() {
    }

    /**
     * Entrada manual. A quantidade pode ser informada na unidade de estoque (sem unidade/embalagem),
     * em outra unidade compatível (ex.: kg para produto em g) ou em embalagens (ex.: 2 caixas).
     */
    public record EntradaRequest(
            @NotNull UUID produtoId,
            @NotNull @DecimalMin(value = "0", inclusive = false) @Digits(integer = 12, fraction = 3) BigDecimal quantidade,
            UUID unidadeId,
            UUID embalagemId,
            @Size(max = 500) String observacao) {
    }

    /** Saída manual: consumo interno, perda/desperdício ou devolução ao fornecedor. */
    public record SaidaRequest(
            @NotNull UUID produtoId,
            @NotNull TipoMovimentacao tipo,
            @NotNull @DecimalMin(value = "0", inclusive = false) @Digits(integer = 12, fraction = 3) BigDecimal quantidade,
            UUID unidadeId,
            UUID embalagemId,
            @Size(max = 500) String observacao) {
    }

    /** Ajuste avulso: informa a quantidade física encontrada e o sistema gera a diferença. */
    public record AjusteRequest(
            @NotNull UUID produtoId,
            @NotNull @DecimalMin("0") @Digits(integer = 12, fraction = 3) BigDecimal quantidadeContada,
            @NotBlank @Size(max = 500) String observacao) {
    }

    public record MovimentacaoResponse(
            UUID id,
            UUID produtoId,
            String produtoNome,
            String unidadeSigla,
            TipoMovimentacao tipo,
            BigDecimal quantidade,
            BigDecimal saldoAnterior,
            BigDecimal saldoPosterior,
            BigDecimal custoUnitario,
            String quantidadeInformada,
            OrigemMovimentacao origem,
            UUID origemId,
            String observacao,
            Instant dataHora) {
    }

    public record PosicaoResponse(
            UUID produtoId,
            String nome,
            String codigoInterno,
            String categoria,
            String tipoProduto,
            String unidadeSigla,
            BigDecimal quantidade,
            BigDecimal reservada,
            BigDecimal disponivel,
            BigDecimal estoqueMinimo,
            BigDecimal custoMedio,
            BigDecimal valorEstoque,
            boolean abaixoMinimo,
            boolean ativo) {
    }

    public record ResumoResponse(long produtosAtivos, long abaixoMinimo, long zerados, BigDecimal valorTotal) {
    }

    /** Filtro da posição de estoque. */
    public enum Situacao { TODOS, ABAIXO_MINIMO, ZERADO }
}
