package br.com.bar.gestao.notificacao.api;

import br.com.bar.gestao.notificacao.application.NotificacaoService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/admin/notificacoes")
@Tag(name = "Notificações")
public class NotificacaoController {

    private final NotificacaoService service;

    public NotificacaoController(NotificacaoService service) {
        this.service = service;
    }

    public record Chaves(@NotBlank @Size(max = 200) String p256dh, @NotBlank @Size(max = 100) String auth) {
    }

    /** Formato do PushSubscription.toJSON() do navegador, mais o nome do aparelho. */
    public record InscricaoRequest(
            @NotBlank @Size(max = 1000) String endpoint,
            @NotNull @Valid Chaves keys,
            @Size(max = 120) String dispositivo) {
    }

    public record RemoverRequest(@NotBlank @Size(max = 1000) String endpoint) {
    }

    @GetMapping("/chave-publica")
    @Operation(summary = "Chave pública VAPID para o navegador assinar a inscrição")
    public Map<String, String> chavePublica() {
        return Map.of("chavePublica", service.chavePublica());
    }

    @GetMapping("/inscricoes")
    @Operation(summary = "Aparelhos que recebem notificações")
    public List<NotificacaoService.Inscricao> inscricoes() {
        return service.inscricoes();
    }

    @PostMapping("/inscricoes")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Inscreve este aparelho para receber notificações de novos pedidos")
    public void inscrever(@Valid @RequestBody InscricaoRequest req, Authentication auth) {
        service.inscrever(req.endpoint(), req.keys().p256dh(), req.keys().auth(), req.dispositivo(),
                auth == null ? null : auth.getName());
    }

    @PostMapping("/inscricoes/remover")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Deixa de receber notificações neste aparelho")
    public void remover(@Valid @RequestBody RemoverRequest req) {
        service.remover(req.endpoint());
    }

    @DeleteMapping("/inscricoes/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void removerPorId(@PathVariable UUID id) {
        service.removerPorId(id);
    }

    @PostMapping("/teste")
    @Operation(summary = "Envia uma notificação de teste para todos os aparelhos")
    public Map<String, Integer> teste() {
        int n = service.enviarParaTodos(new NotificacaoService.Mensagem("Entre Nós · teste",
                "As notificações de novos pedidos estão funcionando neste aparelho.", "/admin/pedidos", "teste"));
        return Map.of("entregues", n);
    }
}
