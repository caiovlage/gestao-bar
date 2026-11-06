package br.com.bar.gestao.despesa.api;

import br.com.bar.gestao.despesa.api.dto.DespesaDto;
import br.com.bar.gestao.despesa.application.DespesaService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.time.ZoneId;
import java.util.UUID;

@RestController
@RequestMapping("/api/admin/despesas")
@Tag(name = "Despesas")
public class DespesaController {

    private final DespesaService service;
    private final ZoneId fuso;

    public DespesaController(DespesaService service, @Value("${app.fuso-horario}") String fuso) {
        this.service = service;
        this.fuso = ZoneId.of(fuso);
    }

    @GetMapping
    @Operation(summary = "Despesas do período (padrão: mês atual) com totais por categoria")
    public DespesaDto.Lista listar(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate inicio,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fim) {
        LocalDate hoje = LocalDate.now(fuso);
        return service.listar(inicio == null ? hoje.withDayOfMonth(1) : inicio, fim == null ? hoje : fim);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public DespesaDto.Response criar(@Valid @RequestBody DespesaDto.Request request) {
        return service.criar(request);
    }

    @PutMapping("/{id}")
    public DespesaDto.Response atualizar(@PathVariable UUID id, @Valid @RequestBody DespesaDto.Request request) {
        return service.atualizar(id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void excluir(@PathVariable UUID id) {
        service.excluir(id);
    }
}
