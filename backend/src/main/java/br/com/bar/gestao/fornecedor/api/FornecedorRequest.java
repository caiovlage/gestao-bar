package br.com.bar.gestao.fornecedor.api;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record FornecedorRequest(
        @NotBlank @Size(max = 120) String nome,
        @Size(max = 120) String nomeFantasia,
        @Pattern(regexp = "^$|^\\d{2}\\.?\\d{3}\\.?\\d{3}/?\\d{4}-?\\d{2}$", message = "CNPJ inválido") String cnpj,
        @Size(max = 20) String telefone,
        @Email @Size(max = 120) String email,
        @Size(max = 250) String endereco,
        @Size(max = 1000) String observacoes) {
}
