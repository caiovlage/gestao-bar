package br.com.bar.gestao.catalogo.api.dto;

import br.com.bar.gestao.catalogo.domain.Produto;
import br.com.bar.gestao.catalogo.domain.ProdutoEmbalagem;
import br.com.bar.gestao.catalogo.domain.TipoProduto;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public final class ProdutoDto {

    private ProdutoDto() {
    }

    public record Request(
            @NotBlank @Size(max = 120) String nome,
            @Size(max = 1000) String descricao,
            UUID categoriaId,
            @NotNull TipoProduto tipo,
            @NotNull UUID unidadeEstoqueId,
            @NotNull @DecimalMin("0") @Digits(integer = 12, fraction = 6) BigDecimal custoMedio,
            @DecimalMin("0") @Digits(integer = 12, fraction = 2) BigDecimal precoVenda,
            @NotNull @DecimalMin("0") @Digits(integer = 12, fraction = 3) BigDecimal estoqueMinimo,
            UUID fornecedorPrincipalId,
            @Size(max = 100) String codigoInterno,
            Boolean vendeNoCardapio,
            @Valid @Size(max = 20) List<EmbalagemRequest> embalagens,
            /** Falso para pratos preparados (sem controle de estoque). Ausente = true. */
            Boolean controlaEstoque,
            /** Preço com desconto (menor que o de venda); nulo = sem promoção. */
            @DecimalMin(value = "0", inclusive = false) @Digits(integer = 12, fraction = 2) BigDecimal precoPromocional,
            /** Último dia da promoção (inclusive); nulo = sem prazo. */
            LocalDate promocaoAte,
            /** "Sugestão da casa" em destaque no cardápio. */
            Boolean destaqueCardapio) {

        public boolean controlarEstoque() {
            return controlaEstoque == null || controlaEstoque;
        }

        public boolean exibirNoCardapio() {
            return Boolean.TRUE.equals(vendeNoCardapio);
        }
    }

    public record EmbalagemRequest(
            UUID id,
            @NotNull UUID unidadeId,
            @NotBlank @Size(max = 60) String descricao,
            @NotNull @DecimalMin(value = "0", inclusive = false) @Digits(integer = 12, fraction = 3) BigDecimal fator) {
    }

    public record Response(
            UUID id,
            String nome,
            String descricao,
            Referencia categoria,
            TipoProduto tipo,
            UnidadeMedidaDto.Response unidadeEstoque,
            BigDecimal custoMedio,
            BigDecimal precoVenda,
            BigDecimal margemBrutaPercentual,
            BigDecimal estoqueAtual,
            BigDecimal estoqueMinimo,
            boolean abaixoMinimo,
            UUID fornecedorPrincipalId,
            String codigoInterno,
            String imagemUrl,
            boolean vendeNoCardapio,
            boolean ativo,
            List<EmbalagemResponse> embalagens,
            boolean controlaEstoque,
            BigDecimal precoPromocional,
            LocalDate promocaoAte,
            boolean destaqueCardapio) {

        public static Response of(Produto p, BigDecimal estoqueAtual) {
            BigDecimal estoque = estoqueAtual == null ? BigDecimal.ZERO : estoqueAtual;
            boolean abaixo = p.isControlaEstoque() && p.getEstoqueMinimo().signum() > 0
                    && estoque.compareTo(p.getEstoqueMinimo()) < 0;
            Referencia categoria = p.getCategoria() == null ? null
                    : new Referencia(p.getCategoria().getId(), p.getCategoria().getNome());
            return new Response(p.getId(), p.getNome(), p.getDescricao(), categoria, p.getTipo(),
                    UnidadeMedidaDto.Response.of(p.getUnidadeEstoque()), p.getCustoMedio(), p.getPrecoVenda(),
                    p.margemBrutaPercentual().orElse(null), estoque, p.getEstoqueMinimo(), abaixo,
                    p.getFornecedorPrincipalId(), p.getCodigoInterno(), p.getImagemUrl(), p.isVendeNoCardapio(),
                    p.isAtivo(), p.getEmbalagens().stream().map(EmbalagemResponse::of).toList(),
                    p.isControlaEstoque(), p.getPrecoPromocional(), p.getPromocaoAte(), p.isDestaqueCardapio());
        }
    }

    public record EmbalagemResponse(UUID id, UnidadeMedidaDto.Response unidade, String descricao, BigDecimal fator) {
        static EmbalagemResponse of(ProdutoEmbalagem e) {
            return new EmbalagemResponse(e.getId(), UnidadeMedidaDto.Response.of(e.getUnidade()), e.getDescricao(), e.getFator());
        }
    }

    public record Referencia(UUID id, String nome) {
    }
}
