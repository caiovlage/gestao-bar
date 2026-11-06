package br.com.bar.gestao.receita.api.dto;

import br.com.bar.gestao.receita.domain.Receita;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.util.UUID;

public final class ReceitaDto {

    private ReceitaDto() {
    }

    /** Ingredientes e modo de preparo em HTML do editor (aceita conteúdo colado de sites); limpos no servidor. */
    public record Request(
            @NotBlank @Size(max = 120) String nome,
            @Size(max = 60) String rendimento,
            @Min(0) @Max(1440) Integer tempoPreparoMin,
            @Size(max = 200_000) String ingredientes,
            @Size(max = 200_000) String modoPreparo) {
    }

    public record Resumo(UUID id, String nome, String fotoUrl, String rendimento, Integer tempoPreparoMin,
                         Instant atualizadoEm) {
        public static Resumo of(Receita r) {
            return new Resumo(r.getId(), r.getNome(), r.getFotoUrl(), r.getRendimento(), r.getTempoPreparoMin(),
                    r.getAtualizadoEm());
        }
    }

    public record Detalhe(UUID id, String nome, String fotoUrl, String rendimento, Integer tempoPreparoMin,
                          String ingredientes, String modoPreparo, Instant atualizadoEm) {
        public static Detalhe of(Receita r) {
            return new Detalhe(r.getId(), r.getNome(), r.getFotoUrl(), r.getRendimento(), r.getTempoPreparoMin(),
                    r.getIngredientes(), r.getModoPreparo(), r.getAtualizadoEm());
        }
    }
}
