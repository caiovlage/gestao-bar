package br.com.bar.gestao.caixa.api.dto;

import br.com.bar.gestao.caixa.domain.Caixa;
import br.com.bar.gestao.caixa.domain.MovimentacaoCaixa;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class CaixaDto {

    private CaixaDto() {
    }

    public record AbrirRequest(
            @NotNull @DecimalMin("0") @Digits(integer = 12, fraction = 2) BigDecimal saldoInicial,
            @Size(max = 500) String observacao) {
    }

    public record MovimentoRequest(
            @NotNull MovimentacaoCaixa.Tipo tipo,
            @NotNull @DecimalMin(value = "0", inclusive = false) @Digits(integer = 12, fraction = 2) BigDecimal valor,
            @NotBlank @Size(max = 300) String motivo) {
    }

    public record FecharRequest(
            @NotNull @DecimalMin("0") @Digits(integer = 12, fraction = 2) BigDecimal saldoContado,
            @Size(max = 500) String observacao) {
    }

    public record MovimentoResponse(UUID id, MovimentacaoCaixa.Tipo tipo, BigDecimal valor, String motivo,
                                    Instant dataHora) {
        public static MovimentoResponse of(MovimentacaoCaixa m) {
            return new MovimentoResponse(m.getId(), m.getTipo(), m.getValor(), m.getMotivo(), m.getDataHora());
        }
    }

    /**
     * Caixa com seus totais: calculados na hora enquanto aberto; congelados após o fechamento.
     * {@code lucroBruto} e {@code vendasCanceladas} são sempre calculados (informativos).
     */
    public record Response(
            UUID id,
            Caixa.Status status,
            Instant abertoEm,
            Instant fechadoEm,
            BigDecimal saldoInicial,
            Caixa.Totais totais,
            BigDecimal lucroBruto,
            int vendasCanceladas,
            BigDecimal saldoContado,
            BigDecimal diferenca,
            String observacaoAbertura,
            String observacaoFechamento,
            List<MovimentoResponse> movimentacoes) {
    }
}
