package br.com.bar.gestao.catalogo.api.dto;

import br.com.bar.gestao.catalogo.domain.Categoria;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.util.UUID;

public final class CategoriaDto {

    private CategoriaDto() {
    }

    public record Request(
            @NotBlank @Size(max = 60) String nome,
            @Min(0) @Max(9999) Integer ordem,
            Boolean exibirCardapio) {
    }

    public record Response(UUID id, String nome, int ordem, boolean exibirCardapio, boolean ativo) {
        public static Response of(Categoria c) {
            return new Response(c.getId(), c.getNome(), c.getOrdem(), c.isExibirCardapio(), c.isAtivo());
        }
    }
}
