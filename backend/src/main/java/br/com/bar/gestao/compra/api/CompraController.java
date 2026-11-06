package br.com.bar.gestao.compra.api;

import br.com.bar.gestao.compra.api.dto.CompraDto;
import br.com.bar.gestao.compra.application.CompraConsultaService;
import br.com.bar.gestao.compra.application.CompraExportacao;
import br.com.bar.gestao.compra.application.CompraService;
import br.com.bar.gestao.compra.domain.Compra;
import br.com.bar.gestao.shared.api.PageResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
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
@RequestMapping("/api/admin/compras")
@Tag(name = "Compras")
public class CompraController {

    private final CompraService service;
    private final CompraConsultaService consulta;
    private final CompraExportacao exportacao;

    public CompraController(CompraService service, CompraConsultaService consulta, CompraExportacao exportacao) {
        this.service = service;
        this.consulta = consulta;
        this.exportacao = exportacao;
    }

    @GetMapping("/sugestoes")
    @Operation(summary = "Produtos abaixo do estoque mínimo, com a quantidade sugerida para repor")
    public List<CompraDto.Sugestao> sugestoes() {
        return consulta.sugestoes();
    }

    @PostMapping("/da-sugestao")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Cria uma lista de compras com os produtos sugeridos selecionados")
    public CompraDto.Response criarDaSugestao(@Valid @RequestBody CompraDto.DaSugestaoRequest request) {
        return service.criarDaSugestao(request);
    }

    @GetMapping("/opcoes/produtos")
    @Operation(summary = "Produtos que podem ser comprados, com embalagens")
    public List<CompraDto.OpcaoProduto> produtosCompraveis() {
        return consulta.produtosCompraveis();
    }

    @GetMapping("/historico-custos")
    @Operation(summary = "Histórico de preços de aquisição de um produto")
    public List<CompraDto.HistoricoCusto> historicoCustos(@RequestParam UUID produtoId) {
        return consulta.historicoCustos(produtoId);
    }

    @GetMapping
    public PageResponse<CompraDto.Resumo> listar(
            @RequestParam(required = false) Compra.Status status,
            @PageableDefault(size = 50, sort = "criadoEm", direction = Sort.Direction.DESC) Pageable pageable) {
        return PageResponse.of(service.listar(status, pageable), r -> r);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Cria uma lista de compras (rascunho)")
    public CompraDto.Response criar(@Valid @RequestBody CompraDto.Request request) {
        return service.criar(request);
    }

    @GetMapping("/{id}")
    public CompraDto.Response buscar(@PathVariable UUID id) {
        return service.buscar(id);
    }

    @PutMapping("/{id}")
    @Operation(summary = "Edita a lista (somente rascunho)")
    public CompraDto.Response atualizar(@PathVariable UUID id, @Valid @RequestBody CompraDto.Request request) {
        return service.atualizar(id, request);
    }

    @PostMapping("/{id}/receber")
    @Operation(summary = "Registra o recebimento: entrada no estoque e atualização do custo médio")
    public CompraDto.Response receber(@PathVariable UUID id) {
        return service.receber(id);
    }

    @PostMapping("/{id}/cancelar")
    public CompraDto.Response cancelar(@PathVariable UUID id) {
        return service.cancelar(id);
    }

    @GetMapping("/{id}/exportar")
    @Operation(summary = "Exporta a lista em PDF (formato=pdf) ou Excel (formato=xlsx)")
    public ResponseEntity<byte[]> exportar(@PathVariable UUID id, @RequestParam(defaultValue = "pdf") String formato) {
        CompraDto.Response compra = service.buscar(id);
        boolean excel = "xlsx".equalsIgnoreCase(formato);
        byte[] conteudo = excel ? exportacao.excel(compra) : exportacao.pdf(compra);
        String nome = "lista-de-compras-" + compra.numero() + (excel ? ".xlsx" : ".pdf");
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.attachment().filename(nome).build().toString())
                .contentType(excel
                        ? MediaType.parseMediaType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
                        : MediaType.APPLICATION_PDF)
                .body(conteudo);
    }
}
