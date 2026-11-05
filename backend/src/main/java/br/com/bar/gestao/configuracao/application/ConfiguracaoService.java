package br.com.bar.gestao.configuracao.application;

import br.com.bar.gestao.configuracao.domain.Configuracao;
import br.com.bar.gestao.configuracao.domain.ConfiguracaoRepository;
import br.com.bar.gestao.shared.exception.NegocioException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.Set;

@Service
public class ConfiguracaoService {

    public static final String NOME_BAR = "nome_bar";
    public static final String CARDAPIO_ABERTO = "cardapio_aberto";
    public static final String PERMITIR_ESTOQUE_NEGATIVO = "permitir_estoque_negativo";

    private static final Set<String> CHAVES_BOOLEANAS = Set.of(CARDAPIO_ABERTO, PERMITIR_ESTOQUE_NEGATIVO);
    private static final Logger log = LoggerFactory.getLogger(ConfiguracaoService.class);

    private final ConfiguracaoRepository repository;

    public ConfiguracaoService(ConfiguracaoRepository repository) {
        this.repository = repository;
    }

    @Transactional(readOnly = true)
    public List<Configuracao> listar() {
        return repository.findAll(Sort.by("chave"));
    }

    @Transactional(readOnly = true)
    public String valor(String chave) {
        return repository.findById(chave).map(Configuracao::getValor).orElse(null);
    }

    @Transactional(readOnly = true)
    public boolean ativo(String chave) {
        return Boolean.parseBoolean(valor(chave));
    }

    /** Atualiza apenas chaves já existentes; chaves desconhecidas são rejeitadas. */
    @Transactional
    public List<Configuracao> atualizar(Map<String, String> valores) {
        valores.forEach((chave, valor) -> {
            Configuracao config = repository.findById(chave)
                    .orElseThrow(() -> new NegocioException("CONFIGURACAO_DESCONHECIDA", "Configuração desconhecida: " + chave));
            String normalizado = valor == null ? "" : valor.trim();
            if (CHAVES_BOOLEANAS.contains(chave) && !normalizado.equals("true") && !normalizado.equals("false")) {
                throw new NegocioException("CONFIGURACAO_INVALIDA", "A configuração " + chave + " aceita apenas true ou false.");
            }
            if (normalizado.isEmpty() || normalizado.length() > 500) {
                throw new NegocioException("CONFIGURACAO_INVALIDA", "Valor inválido para " + chave + ".");
            }
            config.alterarValor(normalizado);
            log.info("Configuração alterada: {}={}", chave, normalizado);
        });
        return listar();
    }
}
