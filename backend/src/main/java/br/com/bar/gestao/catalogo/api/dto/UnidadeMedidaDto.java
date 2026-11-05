package br.com.bar.gestao.catalogo.api.dto;

import br.com.bar.gestao.catalogo.domain.Grandeza;
import br.com.bar.gestao.catalogo.domain.UnidadeMedida;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.util.UUID;

public final class UnidadeMedidaDto {

    private UnidadeMedidaDto() {
    }

    public record Request(
            @NotBlank @Size(max = 10) String sigla,
            @NotBlank @Size(max = 40) String nome,
            @NotNull Grandeza grandeza,
            @DecimalMin(value = "0", inclusive = false) BigDecimal fatorBase) {
    }

    public record Response(UUID id, String sigla, String nome, Grandeza grandeza, BigDecimal fatorBase,
                           boolean unidadeBase) {
        public static Response of(UnidadeMedida u) {
            return new Response(u.getId(), u.getSigla(), u.getNome(), u.getGrandeza(), u.getFatorBase(), u.isUnidadeBase());
        }
    }
}
