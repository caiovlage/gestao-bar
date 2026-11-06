package br.com.bar.gestao.caixa.api;

import br.com.bar.gestao.caixa.api.dto.CaixaDto;
import br.com.bar.gestao.caixa.application.CaixaService;
import br.com.bar.gestao.shared.api.PageResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/admin/caixa")
@Tag(name = "Caixa")
public class CaixaController {

    private final CaixaService service;

    public CaixaController(CaixaService service) {
        this.service = service;
    }

    @GetMapping("/atual")
    @Operation(summary = "Caixa aberto com totais em tempo real (204 se não houver caixa aberto)")
    public ResponseEntity<CaixaDto.Response> atual() {
        return service.atual().map(ResponseEntity::ok).orElse(ResponseEntity.noContent().build());
    }

    @PostMapping("/abrir")
    @ResponseStatus(HttpStatus.CREATED)
    public CaixaDto.Response abrir(@Valid @RequestBody CaixaDto.AbrirRequest request) {
        return service.abrir(request);
    }

    @PostMapping("/movimentacoes")
    @Operation(summary = "Registra suprimento (entrada de dinheiro) ou retirada (sangria)")
    public CaixaDto.Response movimentar(@Valid @RequestBody CaixaDto.MovimentoRequest request) {
        return service.movimentar(request);
    }

    @PostMapping("/fechar")
    @Operation(summary = "Fecha o caixa: apura os totais e compara o dinheiro contado com o esperado")
    public CaixaDto.Response fechar(@Valid @RequestBody CaixaDto.FecharRequest request) {
        return service.fechar(request);
    }

    @GetMapping("/historico")
    public PageResponse<CaixaDto.Response> historico(
            @PageableDefault(size = 30, sort = "abertoEm", direction = Sort.Direction.DESC) Pageable pageable) {
        return PageResponse.of(service.historico(pageable), c -> c);
    }

    @GetMapping("/{id}")
    public CaixaDto.Response buscar(@PathVariable UUID id) {
        return service.buscar(id);
    }
}
