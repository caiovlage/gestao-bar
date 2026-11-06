package br.com.bar.gestao.despesa.api.dto;

import br.com.bar.gestao.despesa.domain.Despesa;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public final class DespesaDto {

    private DespesaDto() {
    }

    public record Request(
            @NotBlank @Size(max = 200) String descricao,
            @NotNull Despesa.Categoria categoria,
            @NotNull @DecimalMin(value = "0", inclusive = false) @Digits(integer = 12, fraction = 2) BigDecimal valor,
            @NotNull LocalDate data,
            UUID fornecedorId,
            @Size(max = 500) String observacao) {
    }

    public record Response(UUID id, String descricao, Despesa.Categoria categoria, BigDecimal valor, LocalDate data,
                           UUID fornecedorId, String fornecedor, String observacao) {
    }

    /** Despesas do período, com o total geral e o total por categoria. */
    public record Lista(List<Response> despesas, BigDecimal total, List<TotalCategoria> porCategoria) {
    }

    public record TotalCategoria(Despesa.Categoria categoria, BigDecimal total) {
    }
}
