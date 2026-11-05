package br.com.bar.gestao.auth.api;

import br.com.bar.gestao.auth.application.AuthService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirements;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;

@RestController
@RequestMapping("/api/auth")
@Tag(name = "Autenticação")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/login")
    @SecurityRequirements
    @Operation(summary = "Autentica o usuário administrativo e retorna um token JWT")
    public LoginResponse login(@Valid @RequestBody LoginRequest request) {
        var token = authService.login(request.login(), request.senha());
        return new LoginResponse(token.token(), "Bearer", token.expiraEm(), request.login().trim());
    }

    @GetMapping("/sessao")
    @Operation(summary = "Retorna o usuário do token atual (usado pelo app para validar a sessão)")
    public SessaoResponse sessao(Authentication authentication) {
        return new SessaoResponse(authentication.getName());
    }

    public record LoginRequest(@NotBlank @Size(max = 60) String login, @NotBlank @Size(max = 200) String senha) {
    }

    public record LoginResponse(String token, String tipo, Instant expiraEm, String login) {
    }

    public record SessaoResponse(String login) {
    }
}
