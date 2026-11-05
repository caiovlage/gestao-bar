package br.com.bar.gestao.catalogo.api;

import br.com.bar.gestao.catalogo.api.dto.UnidadeMedidaDto;
import br.com.bar.gestao.catalogo.application.UnidadeMedidaService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/admin/unidades")
@Tag(name = "Unidades de medida")
public class UnidadeMedidaController {

    private final UnidadeMedidaService service;

    public UnidadeMedidaController(UnidadeMedidaService service) {
        this.service = service;
    }

    @GetMapping
    @Operation(summary = "Lista as unidades de medida")
    public List<UnidadeMedidaDto.Response> listar() {
        return service.listar().stream().map(UnidadeMedidaDto.Response::of).toList();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Cria uma unidade de medida (ex.: fardo, garrafa)")
    public UnidadeMedidaDto.Response criar(@Valid @RequestBody UnidadeMedidaDto.Request request) {
        return UnidadeMedidaDto.Response.of(service.criar(request));
    }
}
