package br.com.bar.gestao.catalogo.api;

import br.com.bar.gestao.catalogo.api.dto.CategoriaDto;
import br.com.bar.gestao.catalogo.application.CategoriaService;
import br.com.bar.gestao.shared.api.StatusRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
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

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/admin/categorias")
@Tag(name = "Categorias")
public class CategoriaController {

    private final CategoriaService service;

    public CategoriaController(CategoriaService service) {
        this.service = service;
    }

    @GetMapping
    @Operation(summary = "Lista categorias ordenadas (filtro opcional por ativo)")
    public List<CategoriaDto.Response> listar(@RequestParam(required = false) Boolean ativo) {
        return service.listar(ativo).stream().map(CategoriaDto.Response::of).toList();
    }

    @GetMapping("/{id}")
    public CategoriaDto.Response buscar(@PathVariable UUID id) {
        return CategoriaDto.Response.of(service.buscar(id));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public CategoriaDto.Response criar(@Valid @RequestBody CategoriaDto.Request request) {
        return CategoriaDto.Response.of(service.criar(request));
    }

    @PutMapping("/{id}")
    public CategoriaDto.Response atualizar(@PathVariable UUID id, @Valid @RequestBody CategoriaDto.Request request) {
        return CategoriaDto.Response.of(service.atualizar(id, request));
    }

    @PatchMapping("/{id}/status")
    @Operation(summary = "Ativa ou inativa a categoria")
    public CategoriaDto.Response alterarStatus(@PathVariable UUID id, @Valid @RequestBody StatusRequest request) {
        return CategoriaDto.Response.of(service.alterarStatus(id, request.ativo()));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Exclui a categoria (somente se não houver produtos vinculados)")
    public void excluir(@PathVariable UUID id) {
        service.excluir(id);
    }
}
