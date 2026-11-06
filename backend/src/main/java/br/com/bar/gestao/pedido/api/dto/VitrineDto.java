package br.com.bar.gestao.pedido.api.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;

/** Vitrine do cardápio: seções de destaque configuráveis. */
public final class VitrineDto {

    private VitrineDto() {
    }

    public enum TipoSecao {
        /** Produtos marcados "Sugestão da casa" no cadastro. */
        SUGESTOES,
        /** Produtos com promoção valendo hoje (maior desconto primeiro). */
        PROMOCOES,
        /** Mais vendidos nos últimos 30 dias. */
        MAIS_PEDIDOS,
        /** Menos vendidos nos últimos 30 dias (inclusive os sem venda): ajuda a girar o estoque. */
        MENOS_PEDIDOS,
        /** Cadastrados mais recentemente. */
        NOVIDADES
    }

    /** Seção na ordem em que aparece no cardápio. */
    public record Secao(
            @NotNull TipoSecao tipo,
            @NotBlank @Size(max = 60) String titulo,
            boolean ativa,
            @Min(1) @Max(12) int quantidade) {
    }

    /** A lista inteira é enviada na ordem desejada (cada tipo uma vez). */
    public record AtualizarRequest(@NotNull @Size(min = 1, max = 5) @Valid List<Secao> secoes) {
    }
}
