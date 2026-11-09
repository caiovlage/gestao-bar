-- =====================================================================
-- Backup diário do banco em um repositório Git privado.
-- O envio é feito por um script no servidor (infra/backup/backup-git.sh,
-- agendado pelo deploy.sh) que lê estas configurações e grava o resultado.
-- =====================================================================
INSERT INTO configuracao (chave, valor, descricao) VALUES
    ('backup_git_ativo',          'false', 'Envia um backup do banco por dia para o repositório Git privado'),
    ('backup_git_repositorio',    '',      'Endereço SSH do repositório privado (ex.: git@github.com:usuario/backups.git)'),
    ('backup_git_horario',        '4',     'Hora do dia (0 a 23, horário do bar) em que o backup é enviado'),
    ('backup_git_manter_dias',    '7',     'Quantos backups diários manter no repositório'),
    ('backup_git_solicitado',     'false', 'Pedido de backup imediato feito pelo painel'),
    -- preenchidos pelo servidor (somente leitura no painel)
    ('backup_git_chave_publica',  '',      'Chave pública SSH do servidor (cadastre como deploy key com escrita)'),
    ('backup_git_ultimo_em',      '',      'Data e hora do último backup tentado'),
    ('backup_git_ultimo_resultado', '',    'Resultado do último backup');
