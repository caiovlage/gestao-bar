package br.com.bar.gestao.shared.api;

import jakarta.validation.constraints.NotNull;

/** Corpo usado para ativar/inativar registros (PATCH .../status). */
public record StatusRequest(@NotNull Boolean ativo) {
}
