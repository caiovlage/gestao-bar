package br.com.bar.gestao.relatorio.api;

import br.com.bar.gestao.relatorio.api.dto.RelatorioDto;
import br.com.bar.gestao.relatorio.application.RelatorioService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;

@RestController
@RequestMapping("/api/admin/relatorios")
@Tag(name = "Dashboard e relatórios")
public class RelatorioController {

    private final RelatorioService service;

    public RelatorioController(RelatorioService service) {
        this.service = service;
    }

    @GetMapping("/painel")
    @Operation(summary = "Indicadores, séries, rankings e estoque do período (padrão: últimos 30 dias)")
    public RelatorioDto.Painel painel(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate inicio,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fim) {
        LocalDate hoje = service.hoje();
        LocalDate ate = fim == null ? hoje : fim;
        return service.painel(inicio == null ? ate.minusDays(29) : inicio, ate);
    }
}
