package br.com.bar.gestao.configuracao.api;

import br.com.bar.gestao.configuracao.application.ConfiguracaoService;
import br.com.bar.gestao.configuracao.domain.Configuracao;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/admin/configuracoes")
@Tag(name = "Configurações")
public class ConfiguracaoController {

    private final ConfiguracaoService service;

    public ConfiguracaoController(ConfiguracaoService service) {
        this.service = service;
    }

    @GetMapping
    @Operation(summary = "Lista as configurações do sistema")
    public List<ConfiguracaoResponse> listar() {
        return service.listar().stream().map(ConfiguracaoResponse::of).toList();
    }

    @PutMapping
    @Operation(summary = "Atualiza configurações existentes (mapa chave → valor)")
    public List<ConfiguracaoResponse> atualizar(@RequestBody Map<String, String> valores) {
        return service.atualizar(valores).stream().map(ConfiguracaoResponse::of).toList();
    }

    public record ConfiguracaoResponse(String chave, String valor, String descricao) {
        static ConfiguracaoResponse of(Configuracao c) {
            return new ConfiguracaoResponse(c.getChave(), c.getValor(), c.getDescricao());
        }
    }
}
