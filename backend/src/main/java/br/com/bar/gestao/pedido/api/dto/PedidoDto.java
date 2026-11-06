package br.com.bar.gestao.pedido.api.dto;

import br.com.bar.gestao.pedido.domain.Pedido;
import br.com.bar.gestao.pedido.domain.PedidoItem;
import br.com.bar.gestao.venda.domain.FormaPagamento;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class PedidoDto {

    private PedidoDto() {
    }

    // ---------------------------------------------------------------- cardápio público

    public record Cardapio(String nomeBar, boolean aberto, List<CategoriaCardapio> categorias) {
    }

    public record CategoriaCardapio(UUID id, String nome, List<ProdutoCardapio> produtos) {
    }

    /** {@code esgotado}: produto com controle de estoque sem saldo disponível. */
    public record ProdutoCardapio(UUID id, String nome, String descricao, BigDecimal preco, String imagemUrl,
                                  boolean esgotado) {
    }

    // ---------------------------------------------------------------- criação (cliente)

    public record ItemRequest(
            @NotNull UUID produtoId,
            @NotNull @Min(1) @Max(50) Integer quantidade,
            @Size(max = 200) String observacao) {
    }

    /**
     * Pedido enviado pelo cardápio. {@code chaveIdempotencia} é gerada pelo app para cada carrinho:
     * reenviar o mesmo pedido (rede instável, duplo toque) devolve o pedido já registrado.
     * Preços não são enviados: o servidor usa os do cadastro.
     */
    public record CriarRequest(
            @NotNull UUID chaveIdempotencia,
            @NotBlank @Size(max = 80) String clienteNome,
            @NotBlank @Size(max = 80) String local,
            @Size(max = 500) String observacao,
            @NotNull @Size(min = 1, max = 30) @Valid List<ItemRequest> itens) {
    }

    // ---------------------------------------------------------------- respostas

    public record ItemResponse(UUID produtoId, String produtoNome, int quantidade, BigDecimal precoUnitario,
                               BigDecimal total, String observacao) {

        static ItemResponse of(PedidoItem i) {
            return new ItemResponse(i.getProdutoId(), i.getProdutoNome(), i.getQuantidade(), i.getPrecoUnitario(),
                    i.getTotal(), i.getObservacao());
        }
    }

    /** O que o cliente vê ao acompanhar o pedido (sem dados internos). */
    public record Acompanhamento(UUID id, long numero, String clienteNome, String local, String observacao,
                                 Pedido.StatusPreparo statusPreparo, Pedido.StatusFinanceiro statusFinanceiro,
                                 BigDecimal total, List<ItemResponse> itens, Instant criadoEm,
                                 String motivoCancelamento) {

        public static Acompanhamento of(Pedido p) {
            return new Acompanhamento(p.getId(), p.getNumero(), p.getClienteNome(), p.getLocal(), p.getObservacao(),
                    p.getStatusPreparo(), p.getStatusFinanceiro(), p.getTotal(),
                    p.getItens().stream().map(ItemResponse::of).toList(), p.getCriadoEm(), p.getMotivoCancelamento());
        }
    }

    public record Detalhe(UUID id, long numero, String clienteNome, String local, String observacao,
                          Pedido.StatusPreparo statusPreparo, Pedido.StatusFinanceiro statusFinanceiro,
                          BigDecimal total, List<ItemResponse> itens, boolean estoqueReservado,
                          String motivoCancelamento, UUID vendaId, Instant criadoEm, Instant aceitoEm,
                          Instant prontoEm, Instant entregueEm, Instant pagoEm, Instant canceladoEm) {

        public static Detalhe of(Pedido p) {
            return new Detalhe(p.getId(), p.getNumero(), p.getClienteNome(), p.getLocal(), p.getObservacao(),
                    p.getStatusPreparo(), p.getStatusFinanceiro(), p.getTotal(),
                    p.getItens().stream().map(ItemResponse::of).toList(), p.isEstoqueReservado(),
                    p.getMotivoCancelamento(), p.getVendaId(), p.getCriadoEm(), p.getAceitoEm(), p.getProntoEm(),
                    p.getEntregueEm(), p.getPagoEm(), p.getCanceladoEm());
        }
    }

    // ---------------------------------------------------------------- ações (painel)

    public record AvancarRequest(@NotNull Pedido.StatusPreparo status) {
    }

    public record CancelarRequest(@NotBlank @Size(max = 500) String motivo) {
    }

    /** Pagamento presencial: gera a venda vinculada ao pedido no caixa aberto. */
    public record PagarRequest(
            @NotNull FormaPagamento formaPagamento,
            @DecimalMin("0") @Digits(integer = 12, fraction = 2) BigDecimal valorRecebido,
            @DecimalMin("0") @Digits(integer = 12, fraction = 2) BigDecimal desconto,
            @DecimalMin("0") @DecimalMax("100") @Digits(integer = 3, fraction = 2) BigDecimal descontoPercentual) {
    }
}
