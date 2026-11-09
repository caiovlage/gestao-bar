package br.com.bar.gestao.comanda.api;

import br.com.bar.gestao.comanda.api.dto.ComandaDto;
import br.com.bar.gestao.comanda.application.ComandaService;
import br.com.bar.gestao.shared.api.PageResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
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

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/admin/comandas")
@Tag(name = "Comandas")
public class ComandaController {

    private final ComandaService service;

    public ComandaController(ComandaService service) {
        this.service = service;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Abre uma comanda (conta) no caixa aberto")
    public ComandaDto.Detalhe abrir(@Valid @RequestBody ComandaDto.AbrirRequest request) {
        return service.abrir(request);
    }

    @GetMapping("/abertas")
    @Operation(summary = "Comandas abertas (mais antigas primeiro)")
    public List<ComandaDto.Detalhe> abertas() {
        return service.abertas();
    }

    @GetMapping
    @Operation(summary = "Histórico de comandas fechadas e canceladas")
    public PageResponse<ComandaDto.Detalhe> historico(@PageableDefault(size = 30) Pageable pageable) {
        return service.historico(pageable);
    }

    @GetMapping("/{id}")
    public ComandaDto.Detalhe buscar(@PathVariable UUID id) {
        return service.buscar(id);
    }

    @PutMapping("/{id}")
    @Operation(summary = "Altera nome, local e observação da comanda aberta")
    public ComandaDto.Detalhe alterar(@PathVariable UUID id, @Valid @RequestBody ComandaDto.AbrirRequest request) {
        return service.alterar(id, request);
    }

    @PostMapping("/{id}/itens")
    @Operation(summary = "Lança um produto (preço de hoje; reserva o estoque dos produtos controlados)")
    public ComandaDto.Detalhe lancar(@PathVariable UUID id, @Valid @RequestBody ComandaDto.LancarRequest request) {
        return service.lancar(id, request);
    }

    @PostMapping("/{id}/itens/{itemId}/retirar")
    @Operation(summary = "Retira unidades de um item (sem quantidade = o item inteiro)")
    public ComandaDto.Detalhe retirar(@PathVariable UUID id, @PathVariable UUID itemId,
                                      @Valid @RequestBody ComandaDto.RetirarRequest request) {
        return service.retirar(id, itemId, request.quantidade());
    }

    @PostMapping("/{id}/fechar")
    @Operation(summary = "Fecha a conta: registra o pagamento e gera a venda no caixa")
    public ComandaDto.Detalhe fechar(@PathVariable UUID id, @Valid @RequestBody ComandaDto.FecharRequest request) {
        return service.fechar(id, request);
    }

    @PostMapping("/{id}/cancelar")
    @Operation(summary = "Cancela a comanda com motivo (devolve as reservas de estoque)")
    public ComandaDto.Detalhe cancelar(@PathVariable UUID id, @Valid @RequestBody ComandaDto.CancelarRequest request) {
        return service.cancelar(id, request.motivo());
    }
}
