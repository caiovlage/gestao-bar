package br.com.bar.gestao;

import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Configurações do backup diário no Git: validação e campos somente leitura. */
class BackupConfigIntegrationTest extends IntegracaoBase {

    private ResultActions configurar(String json) throws Exception {
        return mvc.perform(put("/api/admin/configuracoes").header("Authorization", token)
                .contentType(MediaType.APPLICATION_JSON).content(json));
    }

    @Test
    void validaConfiguracoesDoBackup() throws Exception {
        configurar("""
                {"backup_git_ativo":"true","backup_git_repositorio":"git@github.com:bar/gestao-bar-backups.git",
                 "backup_git_horario":"3","backup_git_manter_dias":"14","backup_git_solicitado":"true"}""")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.chave == 'backup_git_repositorio')].valor")
                        .value("git@github.com:bar/gestao-bar-backups.git"));

        // Endereço com caracteres de shell ou que não é SSH é recusado
        configurar("{\"backup_git_repositorio\":\"git@github.com:bar/x.git; rm -rf /\"}")
                .andExpect(jsonPath("$.codigo").value("REPOSITORIO_INVALIDO"));
        configurar("{\"backup_git_repositorio\":\"https://github.com/bar/x.git\"}")
                .andExpect(jsonPath("$.codigo").value("REPOSITORIO_INVALIDO"));
        configurar("{\"backup_git_repositorio\":\"git@github.com:../../etc\"}")
                .andExpect(jsonPath("$.codigo").value("REPOSITORIO_INVALIDO"));

        configurar("{\"backup_git_horario\":\"24\"}").andExpect(jsonPath("$.codigo").value("CONFIGURACAO_INVALIDA"));
        configurar("{\"backup_git_manter_dias\":\"0\"}").andExpect(jsonPath("$.codigo").value("CONFIGURACAO_INVALIDA"));
        configurar("{\"backup_git_ativo\":\"sim\"}").andExpect(jsonPath("$.codigo").value("CONFIGURACAO_INVALIDA"));

        // Resultado e chave são gravados pelo servidor, não pelo painel
        configurar("{\"backup_git_ultimo_resultado\":\"OK\"}")
                .andExpect(jsonPath("$.codigo").value("CONFIGURACAO_SOMENTE_LEITURA"));
        configurar("{\"backup_git_chave_publica\":\"ssh-ed25519 AAAA\"}")
                .andExpect(jsonPath("$.codigo").value("CONFIGURACAO_SOMENTE_LEITURA"));

        configurar("{\"backup_git_ativo\":\"false\",\"backup_git_solicitado\":\"false\"}").andExpect(status().isOk());
    }
}
