package br.com.bar.gestao.estoque.api;

import br.com.bar.gestao.estoque.api.dto.EstoqueDto;
import br.com.bar.gestao.estoque.application.EstoqueConsultaService;
import br.com.bar.gestao.estoque.application.EstoqueOperacoesService;
import br.com.bar.gestao.estoque.domain.TipoMovimentacao;
import br.com.bar.gestao.shared.api.PageResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.UUID;

@RestController
@RequestMapping("/api/admin/estoque")
@Tag(name = "Estoque")
public class EstoqueController {

    private final EstoqueConsultaService consulta;
    private final EstoqueOperacoesService operacoes;

    public EstoqueController(EstoqueConsultaService consulta, EstoqueOperacoesService operacoes) {
        this.consulta = consulta;
        this.operacoes = operacoes;
    }

    @GetMapping
    @Operation(summary = "Posição atual do estoque por produto (paginado)")
    public PageResponse<EstoqueDto.PosicaoResponse> posicao(
            @RequestParam(required = false) String nome,
            @RequestParam(required = false) UUID categoriaId,
            @RequestParam(required = false) EstoqueDto.Situacao situacao,
            @RequestParam(required = false, defaultValue = "true") Boolean ativo,
            @PageableDefault(size = 50) Pageable pageable) {
        return consulta.posicao(new EstoqueConsultaService.FiltroPosicao(nome, categoriaId, situacao, ativo), pageable);
    }

    @GetMapping("/resumo")
    @Operation(summary = "Totais: produtos ativos, abaixo do mínimo, zerados e valor do estoque")
    public EstoqueDto.ResumoResponse resumo() {
        return consulta.resumo();
    }

    @GetMapping("/movimentacoes")
    @Operation(summary = "Histórico de movimentações (mais recentes primeiro)")
    public PageResponse<EstoqueDto.MovimentacaoResponse> movimentacoes(
            @RequestParam(required = false) UUID produtoId,
            @RequestParam(required = false) TipoMovimentacao tipo,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate inicio,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fim,
            @PageableDefault(size = 50) Pageable pageable) {
        return consulta.movimentacoes(new EstoqueConsultaService.FiltroMovimentacoes(produtoId, tipo, inicio, fim), pageable);
    }

    @PostMapping("/entradas")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Registra entrada manual (aceita kg/L ou embalagens, convertidos para a unidade de estoque)")
    public EstoqueDto.MovimentacaoResponse entrada(@Valid @RequestBody EstoqueDto.EntradaRequest request) {
        return operacoes.registrarEntrada(request);
    }

    @PostMapping("/saidas")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Registra consumo interno, perda ou devolução ao fornecedor")
    public EstoqueDto.MovimentacaoResponse saida(@Valid @RequestBody EstoqueDto.SaidaRequest request) {
        return operacoes.registrarSaida(request);
    }

    @PostMapping("/ajustes")
    @Operation(summary = "Ajusta o saldo para a quantidade física contada (204 se não houver diferença)")
    public ResponseEntity<EstoqueDto.MovimentacaoResponse> ajuste(@Valid @RequestBody EstoqueDto.AjusteRequest request) {
        return operacoes.ajustar(request)
                .map(m -> ResponseEntity.status(HttpStatus.CREATED).body(m))
                .orElse(ResponseEntity.noContent().build());
    }
}
