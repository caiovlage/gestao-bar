package br.com.bar.gestao.venda.api.dto;

import br.com.bar.gestao.venda.domain.FormaPagamento;
import br.com.bar.gestao.venda.domain.Venda;
import br.com.bar.gestao.venda.domain.VendaItem;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class VendaDto {

    private VendaDto() {
    }

    public record ItemRequest(
            @NotNull UUID produtoId,
            @NotNull @DecimalMin(value = "0", inclusive = false) @Digits(integer = 9, fraction = 3) BigDecimal quantidade) {
    }

    /**
     * Venda do PDV. {@code chaveIdempotencia} é gerada pelo PDV para cada carrinho: reenviar a mesma
     * venda (duplo clique, rede instável) devolve a venda já registrada em vez de criar outra.
     */
    public record RegistrarRequest(
            @NotNull UUID chaveIdempotencia,
            @NotNull @Size(min = 1, max = 200) @Valid List<ItemRequest> itens,
            @DecimalMin("0") @Digits(integer = 12, fraction = 2) BigDecimal desconto,
            @DecimalMin("0") @DecimalMax("100") @Digits(integer = 3, fraction = 2) BigDecimal descontoPercentual,
            @NotNull FormaPagamento formaPagamento,
            @DecimalMin("0") @Digits(integer = 12, fraction = 2) BigDecimal valorRecebido,
            @Size(max = 500) String observacao) {
    }

    public record CancelarRequest(@NotBlank @Size(max = 500) String motivo) {
    }

    public record ItemResponse(UUID produtoId, String produtoNome, BigDecimal quantidade, BigDecimal precoUnitario,
                               BigDecimal total, BigDecimal custoUnitario, BigDecimal custoTotal) {
        static ItemResponse of(VendaItem i) {
            return new ItemResponse(i.getProdutoId(), i.getProdutoNome(), i.getQuantidade(), i.getPrecoUnitario(),
                    i.getTotal(), i.getCustoUnitario(), i.getCustoTotal());
        }
    }

    public record Detalhe(
            UUID id,
            long numero,
            Instant dataHora,
            UUID caixaId,
            List<ItemResponse> itens,
            BigDecimal subtotal,
            BigDecimal desconto,
            BigDecimal total,
            BigDecimal custoTotal,
            BigDecimal lucroBruto,
            BigDecimal margemPercentual,
            FormaPagamento formaPagamento,
            BigDecimal valorRecebido,
            BigDecimal troco,
            String observacao,
            Venda.Status status,
            String motivoCancelamento,
            Instant canceladaEm) {

        public static Detalhe of(Venda v) {
            BigDecimal margem = v.getTotal().signum() > 0
                    ? v.getLucroBruto().multiply(BigDecimal.valueOf(100)).divide(v.getTotal(), 2, RoundingMode.HALF_UP)
                    : null;
            return new Detalhe(v.getId(), v.getNumero(), v.getDataHora(), v.getCaixaId(),
                    v.getItens().stream().map(ItemResponse::of).toList(), v.getSubtotal(), v.getDesconto(),
                    v.getTotal(), v.getCustoTotal(), v.getLucroBruto(), margem, v.getFormaPagamento(),
                    v.getValorRecebido(), v.getTroco(), v.getObservacao(), v.getStatus(), v.getMotivoCancelamento(),
                    v.getCanceladaEm());
        }
    }

    public record Resumo(UUID id, long numero, Instant dataHora, BigDecimal total, BigDecimal lucroBruto,
                         FormaPagamento formaPagamento, Venda.Status status, int quantidadeItens, String itens) {
    }

    /**
     * Produto disponível no PDV. {@code precoVenda} é o preço cobrado hoje (promocional, se houver);
     * {@code precoNormal} só vem preenchido durante a promoção. {@code disponivel} é nulo para
     * produtos sem controle de estoque.
     */
    public record ItemCatalogo(UUID produtoId, String nome, BigDecimal precoVenda, UUID categoriaId, String categoria,
                               String imagemUrl, String codigoInterno, boolean controlaEstoque, BigDecimal disponivel,
                               String unidadeSigla, BigDecimal precoNormal) {
    }
}
