#!/usr/bin/env bash
# =============================================================================
#  Gestão do Bar — backup diário do banco em um repositório Git PRIVADO.
#
#  Executado a cada 5 minutos pelo timer do systemd (instalado pelo deploy.sh).
#  Lê as configurações do painel (tabela configuracao) e só faz o backup quando:
#    - "Backup diário no Git" está ligado, já passou da hora escolhida e ainda
#      não houve backup com sucesso hoje; ou
#    - alguém clicou em "Fazer backup agora" no painel.
#
#  O repositório guarda apenas os últimos N backups (gestao-bar-AAAA-MM-DD.sql.gz)
#  em um único commit, enviado com --force: o histórico não cresce sem limite.
#
#  Autenticação: chave SSH própria (deploy key) em .backup-git/id_ed25519,
#  criada pelo deploy.sh. Cadastre a chave pública no repositório com permissão
#  de escrita (GitHub → Settings → Deploy keys → "Allow write access").
#
#  Uso manual:  infra/backup/backup-git.sh [--agora]
# =============================================================================
set -Eeuo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIR="$RAIZ/.backup-git"
CHAVE="$DIR/id_ed25519"
TRABALHO="$DIR/repositorio"
FUSO="${FUSO_HORARIO:-America/Sao_Paulo}"
LIMITE_GITHUB=$((95 * 1024 * 1024))   # GitHub recusa arquivos acima de 100 MB

cd "$RAIZ"
mkdir -p "$DIR"
chmod 700 "$DIR"

# Uma execução por vez
exec 9>"$DIR/.trava"
flock -n 9 || exit 0

if docker info >/dev/null 2>&1; then DOCKER=(docker); else DOCKER=(sudo -n docker); fi

psql_banco() {
  "${DOCKER[@]}" compose exec -T postgres sh -c 'psql -X -q -t -A -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"' psql "$@"
}

config() {
  psql_banco -c "select valor from configuracao where chave = '$1'" | tr -d '\r'
}

# Grava um valor (com aspas tratadas pelo próprio psql: variável :'v')
gravar() {
  printf "update configuracao set valor = :'v', atualizado_em = now() where chave = '%s';\n" "$1" \
    | psql_banco -v v="$2" >/dev/null
}

# Banco fora do ar (ex.: durante o deploy): tenta na próxima execução
if ! psql_banco -c "select 1" >/dev/null 2>&1; then
  exit 0
fi

# Publica a chave pública para o painel mostrar (para cadastrar no GitHub)
if [[ -f "$CHAVE.pub" ]]; then
  PUBLICA="$(cat "$CHAVE.pub")"
  [[ "$(config backup_git_chave_publica)" == "$PUBLICA" ]] || gravar backup_git_chave_publica "$PUBLICA"
fi

ATIVO="$(config backup_git_ativo)"
SOLICITADO="$(config backup_git_solicitado)"
REPOSITORIO="$(config backup_git_repositorio)"
HORARIO="$(config backup_git_horario)"
MANTER="$(config backup_git_manter_dias)"
ULTIMO="$(config backup_git_ultimo_em)"
RESULTADO="$(config backup_git_ultimo_resultado)"

HOJE="$(TZ="$FUSO" date +%F)"
HORA_ATUAL="$(TZ="$FUSO" date +%-H)"

FORCADO=0
[[ "${1:-}" == "--agora" || "$SOLICITADO" == "true" ]] && FORCADO=1

if [[ $FORCADO -eq 0 ]]; then
  [[ "$ATIVO" == "true" ]] || exit 0
  [[ "$HORARIO" =~ ^[0-9]+$ ]] || HORARIO=4
  (( HORA_ATUAL >= HORARIO )) || exit 0
  # já houve backup com sucesso hoje
  [[ "$ULTIMO" == "$HOJE"* && "$RESULTADO" == OK* ]] && exit 0
  # falhou hoje há pouco: tenta de novo só a cada hora
  if [[ "$ULTIMO" == "$HOJE"* && -f "$DIR/.ultima-tentativa" ]] \
     && (( $(date +%s) - $(stat -c %Y "$DIR/.ultima-tentativa") < 3600 )); then
    exit 0
  fi
fi

[[ "$SOLICITADO" == "true" ]] && gravar backup_git_solicitado false
touch "$DIR/.ultima-tentativa"
AGORA="$(TZ="$FUSO" date '+%F %H:%M')"

falhar() {
  gravar backup_git_ultimo_em "$AGORA"
  gravar backup_git_ultimo_resultado "ERRO: $1"
  echo "Backup: ERRO: $1" >&2
  exit 1
}

# Mesma validação do painel: o endereço vira argumento do git
if [[ ! "$REPOSITORIO" =~ ^(git@[A-Za-z0-9.-]+:[A-Za-z0-9._/-]+|ssh://[A-Za-z0-9._@:/-]+)$ ]]; then
  falhar "informe o endereço SSH do repositório em Configurações."
fi
[[ -f "$CHAVE" ]] || falhar "chave SSH não encontrada; rode ./deploy.sh no servidor."
[[ "$MANTER" =~ ^[0-9]+$ ]] && (( MANTER >= 1 )) || MANTER=7

# ----------------------------------------------------------------- dump
mkdir -p "$TRABALHO"
ARQUIVO="gestao-bar-$HOJE.sql.gz"
TEMP="$DIR/$ARQUIVO.tmp"
if ! "${DOCKER[@]}" compose exec -T postgres sh -c \
     'pg_dump --no-owner --no-privileges -U "$POSTGRES_USER" "$POSTGRES_DB"' | gzip -9 > "$TEMP"; then
  rm -f "$TEMP"
  falhar "não foi possível gerar o dump do banco."
fi
TAMANHO=$(stat -c %s "$TEMP")
if (( TAMANHO > LIMITE_GITHUB )); then
  rm -f "$TEMP"
  falhar "backup com $((TAMANHO / 1024 / 1024)) MB passa do limite de arquivo do GitHub (100 MB)."
fi
mv "$TEMP" "$TRABALHO/$ARQUIVO"

# Mantém só os N mais recentes
ls -1 "$TRABALHO"/gestao-bar-*.sql.gz 2>/dev/null | sort -r | tail -n +$((MANTER + 1)) | xargs -r rm -f

cat > "$TRABALHO/README.md" <<EOF
# Backups — Gestão do Bar

Backups diários do banco PostgreSQL (últimos $MANTER), gerados automaticamente pelo servidor.
**Mantenha este repositório privado**: contém todos os dados do bar.

Restaurar (no servidor, na pasta do projeto): veja "Restaurar um backup" em docs/instalacao.md.

Último backup: $AGORA
EOF

# ----------------------------------------------------------------- envio
# Um único commit com os arquivos atuais, enviado com --force (histórico enxuto).
export GIT_SSH_COMMAND="ssh -i '$CHAVE' -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile='$DIR/known_hosts'"
SAIDA="$DIR/.saida-git"
if ! (
  cd "$TRABALHO"
  rm -rf .git
  git init -q -b main
  git -c user.name="Gestão do Bar" -c user.email="backup@gestao-bar.local" add -A
  git -c user.name="Gestão do Bar" -c user.email="backup@gestao-bar.local" commit -q -m "Backup $AGORA"
  git push -q --force -- "$REPOSITORIO" main
) >"$SAIDA" 2>&1; then
  ERRO="$( (grep -v '^\s*$' "$SAIDA" || true) | tail -n 2 | tr '\n' ' ' | cut -c1-300)"
  if grep -qiE "permission denied|denied to deploy key|read only|not authorized" "$SAIDA"; then
    ERRO="sem permissão no repositório. Cadastre a chave pública como deploy key com escrita. ($ERRO)"
  elif grep -qiE "repository not found|does not appear to be a git repository" "$SAIDA"; then
    ERRO="repositório não encontrado (endereço errado ou chave sem acesso). ($ERRO)"
  fi
  falhar "$ERRO"
fi

TEXTO_TAMANHO="$(numfmt --to=iec --suffix=B "$TAMANHO" 2>/dev/null || echo "$TAMANHO bytes")"
gravar backup_git_ultimo_em "$AGORA"
gravar backup_git_ultimo_resultado "OK · $ARQUIVO · $TEXTO_TAMANHO"
echo "Backup enviado: $ARQUIVO ($TEXTO_TAMANHO)"
