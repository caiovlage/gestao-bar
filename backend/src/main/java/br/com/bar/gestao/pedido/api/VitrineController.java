package br.com.bar.gestao.pedido.api;

import br.com.bar.gestao.pedido.api.dto.VitrineDto;
import br.com.bar.gestao.pedido.application.VitrineService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/admin/cardapio/vitrine")
@Tag(name = "Pedidos")
public class VitrineController {

    private final VitrineService service;

    public VitrineController(VitrineService service) {
        this.service = service;
    }

    @GetMapping
    @Operation(summary = "Seções de destaque do cardápio, na ordem em que aparecem")
    public List<VitrineDto.Secao> listar() {
        return service.listar();
    }

    @PutMapping
    @Operation(summary = "Define as seções (ordem da lista = ordem no cardápio), títulos, quantidades e quais aparecem")
    public List<VitrineDto.Secao> atualizar(@Valid @RequestBody VitrineDto.AtualizarRequest request) {
        return service.atualizar(request.secoes());
    }
}
