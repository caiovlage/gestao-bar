package br.com.bar.gestao.compra.api.dto;

import br.com.bar.gestao.compra.domain.Compra;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class CompraDto {

    private CompraDto() {
    }

    /**
     * Item da lista: quantidade na unidade de estoque (sem unidade/embalagem), em outra unidade
     * compatível (kg) ou em embalagens (caixas); {@code custoUnitario} é o preço por essa unidade.
     */
    public record ItemRequest(
            @NotNull UUID produtoId,
            @NotNull @DecimalMin(value = "0", inclusive = false) @Digits(integer = 12, fraction = 3) BigDecimal quantidade,
            UUID unidadeId,
            UUID embalagemId,
            @NotNull @DecimalMin("0") @Digits(integer = 10, fraction = 4) BigDecimal custoUnitario) {
    }

    public record Request(
            UUID fornecedorId,
            @Size(max = 500) String observacao,
            @NotNull @Size(max = 300) @Valid List<ItemRequest> itens) {
    }

    /** Gera uma lista de compras a partir das sugestões selecionadas. */
    public record DaSugestaoRequest(@NotEmpty @Size(max = 300) List<UUID> produtoIds, UUID fornecedorId) {
    }

    public record Sugestao(
            UUID produtoId,
            String nome,
            String categoria,
            String unidadeSigla,
            BigDecimal estoqueAtual,
            BigDecimal estoqueMinimo,
            BigDecimal sugerido,
            BigDecimal custoMedio,
            UUID fornecedorId,
            String fornecedor,
            String embalagem,
            BigDecimal sugeridoEmbalagens) {
    }

    public record ItemResponse(
            UUID produtoId,
            String produtoNome,
            BigDecimal quantidade,
            UUID unidadeId,
            UUID embalagemId,
            String unidadeCompra,
            BigDecimal quantidadeEstoque,
            String unidadeEstoque,
            BigDecimal custoUnitario,
            BigDecimal custoTotal) {
    }

    public record Response(
            UUID id,
            long numero,
            Compra.Status status,
            UUID fornecedorId,
            String fornecedor,
            String observacao,
            BigDecimal total,
            Instant criadaEm,
            Instant recebidaEm,
            Instant canceladaEm,
            List<ItemResponse> itens) {
    }

    public record Resumo(UUID id, long numero, Compra.Status status, String fornecedor, BigDecimal total,
                         int quantidadeItens, Instant criadaEm, Instant recebidaEm) {
    }

    public record OpcaoEmbalagem(UUID id, String descricao, BigDecimal fator) {
    }

    /** Produto comprável, para a tela de lista de compras. */
    public record OpcaoProduto(UUID id, String nome, UUID unidadeId, String unidadeSigla, String grandeza,
                               BigDecimal custoMedio, UUID fornecedorId, List<OpcaoEmbalagem> embalagens) {
    }

    public record HistoricoCusto(Instant dataHora, long compraNumero, String fornecedor, BigDecimal quantidade,
                                 BigDecimal custoUnitario, BigDecimal custoMedioAnterior, BigDecimal custoMedioNovo) {
    }
}
