package br.com.bar.gestao.fornecedor.api;

import br.com.bar.gestao.fornecedor.application.FornecedorService;
import br.com.bar.gestao.fornecedor.domain.Fornecedor;
import br.com.bar.gestao.shared.api.PageResponse;
import br.com.bar.gestao.shared.api.StatusRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/admin/fornecedores")
@Tag(name = "Fornecedores")
public class FornecedorController {

    private final FornecedorService service;

    public FornecedorController(FornecedorService service) {
        this.service = service;
    }

    @GetMapping
    @Operation(summary = "Pesquisa fornecedores (paginado)")
    public PageResponse<FornecedorResponse> pesquisar(@RequestParam(required = false) String nome,
                                                      @RequestParam(required = false) Boolean ativo,
                                                      @PageableDefault(sort = "nome", direction = Sort.Direction.ASC) Pageable pageable) {
        return PageResponse.of(service.pesquisar(nome, ativo, pageable), FornecedorResponse::of);
    }

    @GetMapping("/{id}")
    public FornecedorResponse buscar(@PathVariable UUID id) {
        return FornecedorResponse.of(service.buscar(id));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public FornecedorResponse criar(@Valid @RequestBody FornecedorRequest request) {
        return FornecedorResponse.of(service.criar(request));
    }

    @PutMapping("/{id}")
    public FornecedorResponse atualizar(@PathVariable UUID id, @Valid @RequestBody FornecedorRequest request) {
        return FornecedorResponse.of(service.atualizar(id, request));
    }

    @PatchMapping("/{id}/status")
    @Operation(summary = "Ativa ou inativa o fornecedor")
    public FornecedorResponse alterarStatus(@PathVariable UUID id, @Valid @RequestBody StatusRequest request) {
        return FornecedorResponse.of(service.alterarStatus(id, request.ativo()));
    }

    public record FornecedorResponse(UUID id, String nome, String nomeFantasia, String cnpj, String telefone,
                                     String email, String endereco, String observacoes, boolean ativo) {
        static FornecedorResponse of(Fornecedor f) {
            return new FornecedorResponse(f.getId(), f.getNome(), f.getNomeFantasia(), f.getCnpj(), f.getTelefone(),
                    f.getEmail(), f.getEndereco(), f.getObservacoes(), f.isAtivo());
        }
    }
}
