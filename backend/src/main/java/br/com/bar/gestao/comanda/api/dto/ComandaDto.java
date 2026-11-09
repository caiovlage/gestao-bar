package br.com.bar.gestao.comanda.api.dto;

import br.com.bar.gestao.comanda.domain.Comanda;
import br.com.bar.gestao.comanda.domain.ComandaItem;
import br.com.bar.gestao.venda.domain.FormaPagamento;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class ComandaDto {

    private ComandaDto() {
    }

    public record AbrirRequest(
            @NotBlank @Size(max = 80) String clienteNome,
            @Size(max = 80) String local,
            @Size(max = 500) String observacao) {
    }

    public record LancarRequest(
            @NotNull UUID produtoId,
            @NotNull @DecimalMin(value = "0", inclusive = false) @Digits(integer = 9, fraction = 3) BigDecimal quantidade,
            @Size(max = 200) String observacao) {
    }

    /** {@code quantidade} nula = retira a linha inteira. */
    public record RetirarRequest(
            @DecimalMin(value = "0", inclusive = false) @Digits(integer = 9, fraction = 3) BigDecimal quantidade) {
    }

    public record FecharRequest(
            @NotNull FormaPagamento formaPagamento,
            @DecimalMin("0") @Digits(integer = 12, fraction = 2) BigDecimal valorRecebido,
            @DecimalMin("0") @Digits(integer = 12, fraction = 2) BigDecimal desconto,
            @DecimalMin("0") @DecimalMax("100") @Digits(integer = 3, fraction = 2) BigDecimal descontoPercentual) {
    }

    public record CancelarRequest(@NotBlank @Size(max = 500) String motivo) {
    }

    public record ItemResponse(UUID id, UUID produtoId, String produtoNome, BigDecimal quantidade,
                               BigDecimal precoUnitario, BigDecimal total, String observacao, Instant lancadoEm) {

        static ItemResponse of(ComandaItem i) {
            return new ItemResponse(i.getId(), i.getProdutoId(), i.getProdutoNome(), i.getQuantidade(),
                    i.getPrecoUnitario(), i.getTotal(), i.getObservacao(), i.getLancadoEm());
        }
    }

    public record Detalhe(UUID id, long numero, UUID caixaId, String clienteNome, String local, String observacao,
                          Comanda.Status status, BigDecimal total, List<ItemResponse> itens, UUID vendaId,
                          String motivoCancelamento, Instant abertaEm, Instant fechadaEm, Instant canceladaEm) {

        public static Detalhe of(Comanda c) {
            return new Detalhe(c.getId(), c.getNumero(), c.getCaixaId(), c.getClienteNome(), c.getLocal(),
                    c.getObservacao(), c.getStatus(), c.getTotal(), c.getItens().stream().map(ItemResponse::of).toList(),
                    c.getVendaId(), c.getMotivoCancelamento(), c.getCriadoEm(), c.getFechadaEm(), c.getCanceladaEm());
        }
    }
}
