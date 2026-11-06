package br.com.bar.gestao.receita.api;

import br.com.bar.gestao.receita.api.dto.ReceitaDto;
import br.com.bar.gestao.receita.application.ReceitaService;
import br.com.bar.gestao.shared.api.PageResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.UUID;

@RestController
@RequestMapping("/api/admin/receitas")
@Tag(name = "Receitas")
public class ReceitaController {

    private final ReceitaService service;

    public ReceitaController(ReceitaService service) {
        this.service = service;
    }

    @GetMapping
    @Operation(summary = "Pesquisa receitas por nome (paginado)")
    public PageResponse<ReceitaDto.Resumo> pesquisar(
            @RequestParam(required = false) String nome,
            @PageableDefault(size = 100, sort = "nome", direction = Sort.Direction.ASC) Pageable pageable) {
        return PageResponse.of(service.pesquisar(nome, pageable), r -> r);
    }

    @GetMapping("/{id}")
    public ReceitaDto.Detalhe buscar(@PathVariable UUID id) {
        return service.buscar(id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Cadastra receita (ingredientes e modo de preparo aceitam HTML colado de sites)")
    public ReceitaDto.Detalhe criar(@Valid @RequestBody ReceitaDto.Request request) {
        return service.criar(request);
    }

    @PutMapping("/{id}")
    public ReceitaDto.Detalhe atualizar(@PathVariable UUID id, @Valid @RequestBody ReceitaDto.Request request) {
        return service.atualizar(id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void excluir(@PathVariable UUID id) {
        service.excluir(id);
    }

    @PostMapping(path = "/{id}/foto", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "Envia/substitui a foto da receita (JPG, PNG ou WEBP, até 5 MB)")
    public ReceitaDto.Detalhe enviarFoto(@PathVariable UUID id, @RequestPart("arquivo") MultipartFile arquivo) {
        return service.definirFoto(id, arquivo);
    }

    @DeleteMapping("/{id}/foto")
    public ReceitaDto.Detalhe removerFoto(@PathVariable UUID id) {
        return service.removerFoto(id);
    }
}
