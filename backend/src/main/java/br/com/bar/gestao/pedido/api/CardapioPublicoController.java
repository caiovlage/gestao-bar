package br.com.bar.gestao.pedido.api;

import br.com.bar.gestao.pedido.api.dto.PedidoDto;
import br.com.bar.gestao.pedido.application.CardapioService;
import br.com.bar.gestao.pedido.application.PedidoService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirements;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.CacheControl;
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

/** Endpoints sem login usados pelo cardápio digital do cliente. */
@RestController
@RequestMapping("/api/public")
@Tag(name = "Público")
@SecurityRequirements
public class CardapioPublicoController {

    private final CardapioService cardapio;
    private final PedidoService pedidos;

    public CardapioPublicoController(CardapioService cardapio, PedidoService pedidos) {
        this.cardapio = cardapio;
        this.pedidos = pedidos;
    }

    @GetMapping("/cardapio")
    @Operation(summary = "Cardápio: nome do bar, se aceita pedidos e produtos por categoria")
    public ResponseEntity<PedidoDto.Cardapio> cardapio() {
        return ResponseEntity.ok().cacheControl(CacheControl.noCache()).body(cardapio.cardapio());
    }

    @PostMapping("/pedidos")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Envia um pedido (idempotente pela chave do carrinho; preços definidos pelo servidor)")
    public PedidoDto.Acompanhamento criar(@Valid @RequestBody PedidoDto.CriarRequest request,
                                          HttpServletRequest http) {
        return pedidos.criar(request, ipOrigem(http));
    }

    @GetMapping("/pedidos/{id}")
    @Operation(summary = "Acompanhamento do pedido pelo cliente")
    public ResponseEntity<PedidoDto.Acompanhamento> acompanhar(@PathVariable UUID id) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(pedidos.acompanhar(id));
    }

    /**
     * O backend só escuta em 127.0.0.1 e recebe tudo pelo nginx, que define X-Real-IP com o IP
     * real do cliente; sem o cabeçalho (acesso direto), usa o endereço da conexão.
     */
    private static String ipOrigem(HttpServletRequest http) {
        String real = http.getHeader("X-Real-IP");
        String ip = real == null || real.isBlank() ? http.getRemoteAddr() : real.trim();
        return ip.length() > 64 ? ip.substring(0, 64) : ip;
    }
}
