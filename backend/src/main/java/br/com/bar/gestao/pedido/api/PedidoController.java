package br.com.bar.gestao.pedido.api;

import br.com.bar.gestao.pedido.api.dto.PedidoDto;
import br.com.bar.gestao.pedido.application.PedidoService;
import br.com.bar.gestao.shared.api.PageResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/admin/pedidos")
@Tag(name = "Pedidos")
public class PedidoController {

    private final PedidoService service;

    public PedidoController(PedidoService service) {
        this.service = service;
    }

    @GetMapping("/em-andamento")
    @Operation(summary = "Pedidos em andamento (painel/kanban): não cancelados e ainda não entregues e pagos")
    public List<PedidoDto.Detalhe> emAndamento() {
        return service.emAndamento();
    }

    @GetMapping
    @Operation(summary = "Histórico de pedidos (mais recentes primeiro)")
    public PageResponse<PedidoDto.Detalhe> historico(@PageableDefault(size = 50) Pageable pageable) {
        return service.historico(pageable);
    }

    @GetMapping("/{id}")
    public PedidoDto.Detalhe buscar(@PathVariable UUID id) {
        return service.buscar(id);
    }

    @PostMapping("/{id}/aceitar")
    @Operation(summary = "Aceita o pedido e reserva o estoque dos produtos controlados")
    public PedidoDto.Detalhe aceitar(@PathVariable UUID id) {
        return service.aceitar(id);
    }

    @PostMapping("/{id}/status")
    @Operation(summary = "Avança o preparo: EM_PREPARO, PRONTO ou ENTREGUE")
    public PedidoDto.Detalhe avancar(@PathVariable UUID id, @Valid @RequestBody PedidoDto.AvancarRequest request) {
        return service.avancar(id, request.status());
    }

    @PostMapping("/{id}/cancelar")
    @Operation(summary = "Recusa ou cancela com motivo, liberando a reserva de estoque")
    public PedidoDto.Detalhe cancelar(@PathVariable UUID id, @Valid @RequestBody PedidoDto.CancelarRequest request) {
        return service.cancelar(id, request.motivo());
    }

    @PostMapping("/{id}/pagar")
    @Operation(summary = "Registra o pagamento presencial e gera a venda (exige caixa aberto)")
    public PedidoDto.Detalhe pagar(@PathVariable UUID id, @Valid @RequestBody PedidoDto.PagarRequest request) {
        return service.pagar(id, request);
    }
}
