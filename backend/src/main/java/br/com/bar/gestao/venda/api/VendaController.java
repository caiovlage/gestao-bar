package br.com.bar.gestao.venda.api;

import br.com.bar.gestao.shared.api.PageResponse;
import br.com.bar.gestao.venda.api.dto.VendaDto;
import br.com.bar.gestao.venda.application.VendaConsultaService;
import br.com.bar.gestao.venda.application.VendaService;
import br.com.bar.gestao.venda.domain.Venda;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/admin/vendas")
@Tag(name = "Vendas")
public class VendaController {

    private final VendaService service;
    private final VendaConsultaService consulta;

    public VendaController(VendaService service, VendaConsultaService consulta) {
        this.service = service;
        this.consulta = consulta;
    }

    @GetMapping("/catalogo")
    @Operation(summary = "Produtos à venda no PDV (ativos, vendáveis e com preço), por categoria")
    public List<VendaDto.ItemCatalogo> catalogo() {
        return consulta.catalogo();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Registra uma venda (exige caixa aberto; idempotente pela chave do carrinho)")
    public VendaDto.Detalhe registrar(@Valid @RequestBody VendaDto.RegistrarRequest request) {
        return service.registrar(request);
    }

    @GetMapping
    @Operation(summary = "Histórico de vendas (mais recentes primeiro)")
    public PageResponse<VendaDto.Resumo> pesquisar(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate inicio,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fim,
            @RequestParam(required = false) Venda.Status status,
            @RequestParam(required = false) UUID caixaId,
            @RequestParam(required = false) Long numero,
            @PageableDefault(size = 50) Pageable pageable) {
        return consulta.pesquisar(new VendaConsultaService.Filtro(inicio, fim, status, caixaId, numero), pageable);
    }

    @GetMapping("/{id}")
    public VendaDto.Detalhe buscar(@PathVariable UUID id) {
        return service.buscar(id);
    }

    @PostMapping("/{id}/cancelar")
    @Operation(summary = "Cancela com justificativa e estorna o estoque (só com o caixa da venda aberto)")
    public VendaDto.Detalhe cancelar(@PathVariable UUID id, @Valid @RequestBody VendaDto.CancelarRequest request) {
        return service.cancelar(id, request.motivo());
    }
}
