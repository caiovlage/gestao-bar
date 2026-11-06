package br.com.bar.gestao.estoque.api.dto;

import br.com.bar.gestao.estoque.domain.Inventario;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class InventarioDto {

    private InventarioDto() {
    }

    /** Abre um inventário com todos os produtos ativos (ou apenas os de uma categoria). */
    public record CriarRequest(@NotBlank @Size(max = 120) String descricao, UUID categoriaId) {
    }

    /** Contagens a registrar; quantidadeContada nula desfaz a contagem do item. */
    public record ContagensRequest(@NotNull @Valid @Size(max = 2000) List<Contagem> contagens) {
    }

    public record Contagem(
            @NotNull UUID produtoId,
            @DecimalMin("0") @Digits(integer = 12, fraction = 3) BigDecimal quantidadeContada) {
    }

    public record EncerrarRequest(@Size(max = 500) String observacao) {
    }

    public record ResumoResponse(UUID id, String descricao, String categoria, Inventario.Status status,
                                 int totalItens, int itensContados, Instant criadoEm, Instant concluidoEm,
                                 Instant canceladoEm) {
    }

    public record DetalheResponse(UUID id, String descricao, String categoria, Inventario.Status status,
                                  String observacao, Instant criadoEm, Instant concluidoEm, Instant canceladoEm,
                                  int totalItens, int itensContados, int itensComDiferenca,
                                  List<ItemResponse> itens) {
    }

    /**
     * Item do inventário. Enquanto aberto, {@code quantidadeSistema} é o saldo atual e {@code diferenca}
     * uma prévia; após concluir, ambos ficam congelados com os valores usados no ajuste.
     */
    public record ItemResponse(UUID produtoId, String produtoNome, String categoria, String unidadeSigla,
                               BigDecimal quantidadeSistema, BigDecimal quantidadeContada, BigDecimal diferenca,
                               BigDecimal custoUnitario, BigDecimal valorDiferenca) {
    }
}
