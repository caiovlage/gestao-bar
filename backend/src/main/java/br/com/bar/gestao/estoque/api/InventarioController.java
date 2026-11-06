package br.com.bar.gestao.estoque.api;

import br.com.bar.gestao.estoque.api.dto.InventarioDto;
import br.com.bar.gestao.estoque.application.InventarioService;
import br.com.bar.gestao.shared.api.PageResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/admin/estoque/inventarios")
@Tag(name = "Inventário")
public class InventarioController {

    private final InventarioService service;

    public InventarioController(InventarioService service) {
        this.service = service;
    }

    @GetMapping
    @Operation(summary = "Lista inventários (mais recentes primeiro)")
    public PageResponse<InventarioDto.ResumoResponse> listar(
            @PageableDefault(sort = "criadoEm", direction = Sort.Direction.DESC) Pageable pageable) {
        return PageResponse.of(service.listar(pageable), r -> r);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Abre um inventário com os produtos ativos (opcionalmente de uma categoria)")
    public InventarioDto.DetalheResponse criar(@Valid @RequestBody InventarioDto.CriarRequest request) {
        return service.criar(request);
    }

    @GetMapping("/{id}")
    public InventarioDto.DetalheResponse buscar(@PathVariable UUID id) {
        return service.buscar(id);
    }

    @PutMapping("/{id}/contagens")
    @Operation(summary = "Registra quantidades contadas (pode ser feito aos poucos)")
    public InventarioDto.DetalheResponse contagens(@PathVariable UUID id,
                                                   @Valid @RequestBody InventarioDto.ContagensRequest request) {
        return service.registrarContagens(id, request);
    }

    @PostMapping("/{id}/concluir")
    @Operation(summary = "Conclui: gera ajustes de estoque para os itens contados com diferença")
    public InventarioDto.DetalheResponse concluir(@PathVariable UUID id,
                                                  @Valid @RequestBody(required = false) InventarioDto.EncerrarRequest request) {
        return service.concluir(id, request);
    }

    @PostMapping("/{id}/cancelar")
    @Operation(summary = "Cancela o inventário sem alterar o estoque")
    public InventarioDto.DetalheResponse cancelar(@PathVariable UUID id,
                                                  @Valid @RequestBody(required = false) InventarioDto.EncerrarRequest request) {
        return service.cancelar(id, request);
    }
}
