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
import java.util.regex.Pattern;

@Service
public class ConfiguracaoService {

    public static final String NOME_BAR = "nome_bar";
    public static final String CARDAPIO_SUBTITULO = "cardapio_subtitulo";
    public static final String CARDAPIO_SLOGAN = "cardapio_slogan";
    public static final String CARDAPIO_ABERTO = "cardapio_aberto";
    public static final String PERMITIR_ESTOQUE_NEGATIVO = "permitir_estoque_negativo";

    public static final String BACKUP_GIT_ATIVO = "backup_git_ativo";
    public static final String BACKUP_GIT_REPOSITORIO = "backup_git_repositorio";
    public static final String BACKUP_GIT_HORARIO = "backup_git_horario";
    public static final String BACKUP_GIT_MANTER_DIAS = "backup_git_manter_dias";
    public static final String BACKUP_GIT_SOLICITADO = "backup_git_solicitado";

    private static final Set<String> CHAVES_BOOLEANAS =
            Set.of(CARDAPIO_ABERTO, PERMITIR_ESTOQUE_NEGATIVO, BACKUP_GIT_ATIVO, BACKUP_GIT_SOLICITADO);

    /** Gravadas pelo script de backup do servidor; o painel só lê. */
    private static final Set<String> SOMENTE_LEITURA =
            Set.of("backup_git_chave_publica", "backup_git_ultimo_em", "backup_git_ultimo_resultado");

    /**
     * Endereço SSH de repositório: git@host:caminho.git ou ssh://... — sem espaços nem caracteres
     * de shell, pois o script do servidor usa o valor como remoto do git.
     */
    private static final Pattern REPOSITORIO_SSH =
            Pattern.compile("^(git@[A-Za-z0-9.-]+:[A-Za-z0-9._/-]+|ssh://[A-Za-z0-9._@:/-]+)$");
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
            if (SOMENTE_LEITURA.contains(chave)) {
                throw new NegocioException("CONFIGURACAO_SOMENTE_LEITURA", "A configuração " + chave + " é preenchida pelo servidor.");
            }
            validarBackup(chave, normalizado);
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

    private static void validarBackup(String chave, String valor) {
        switch (chave) {
            case BACKUP_GIT_REPOSITORIO -> {
                if (!REPOSITORIO_SSH.matcher(valor).matches() || valor.contains("..")) {
                    throw new NegocioException("REPOSITORIO_INVALIDO",
                            "Informe o endereço SSH do repositório, ex.: git@github.com:usuario/gestao-bar-backups.git");
                }
            }
            case BACKUP_GIT_HORARIO -> exigirInteiro(valor, 0, 23, "A hora do backup deve ser de 0 a 23.");
            case BACKUP_GIT_MANTER_DIAS -> exigirInteiro(valor, 1, 30, "Mantenha de 1 a 30 backups.");
            default -> {
            }
        }
    }

    private static void exigirInteiro(String valor, int min, int max, String mensagem) {
        try {
            int n = Integer.parseInt(valor);
            if (n < min || n > max) throw new NumberFormatException();
        } catch (NumberFormatException e) {
            throw new NegocioException("CONFIGURACAO_INVALIDA", mensagem);
        }
    }
}
