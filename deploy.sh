#!/usr/bin/env bash
# =============================================================================
#  Gestão do Bar — instalação e atualização completa no Oracle Linux 8/9
#
#  Uso (na pasta do projeto):   ./deploy.sh [opções]
#
#  Na primeira execução instala e configura tudo (Docker, nginx, Flutter, .env,
#  SELinux, firewall). Nas seguintes, atualiza o código e sobe banco de dados,
#  painel (frontend) e backend, com backup do banco antes de atualizar.
#  Pode ser executado quantas vezes quiser.
#
#  Opções:
#    --forcar        descarta alterações locais e iguala o código ao GitHub
#    -y, --sim       não pede confirmação (usado com --forcar)
#    --limpo         recompila tudo do zero (sem cache do Flutter e do Docker)
#    --so-painel     atualiza apenas o frontend (painel e cardápio)
#    --so-backend    atualiza apenas o backend
#    --sem-pull      não baixa código novo do GitHub
#    --sem-backup    não faz backup do banco antes de atualizar
#    --branch NOME   branch do GitHub (padrão: main)
#    -h, --help      mostra esta ajuda
#
#  Preserva sempre: .env, banco de dados, imagens dos produtos,
#  configuração do nginx em /etc e certificados HTTPS.
# =============================================================================

# Todo o script fica dentro de main(): o bash lê o arquivo inteiro antes de executar,
# então um "git pull" que altere este arquivo não interfere na execução em andamento.
main() {
  set -Eeuo pipefail
  # Nenhuma falha silenciosa: mostra a linha e o comando que falhou.
  trap 'printf "\n\033[31m✘ Falhou na linha %s: %s\033[0m\n" "$LINENO" "$BASH_COMMAND" >&2' ERR

  local RAIZ; RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "$RAIZ"

  # ------------------------------------------------------------------ opções
  local FORCAR=0 CONFIRMAR=1 LIMPO=0 PAINEL=1 BACKEND=1 PULL=1 BACKUP=1 BRANCH=main
  local ARGS_ORIGINAIS=("$@")
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --forcar)     FORCAR=1 ;;
      -y|--sim)     CONFIRMAR=0 ;;
      --limpo)      LIMPO=1 ;;
      --so-painel)  BACKEND=0 ;;
      --so-backend) PAINEL=0 ;;
      --sem-pull)   PULL=0 ;;
      --sem-backup) BACKUP=0 ;;
      --branch)     BRANCH="${2:?informe o nome da branch}"; shift ;;
      -h|--help)    sed -n '3,/^# ====/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
      *) erro "Opção desconhecida: $1 (use --help)" ;;
    esac
    shift
  done

  # ------------------------------------------------------------------ constantes
  local WEB_DIR=/var/www/gestao-bar/admin
  local CARDAPIO_DIR=/var/www/gestao-bar/cardapio
  local NGINX_CONF=/etc/nginx/conf.d/gestao-bar.conf
  local FLUTTER_DIR=/opt/flutter
  local FLUTTER_MIN=3.47.0
  local PROJETO; PROJETO="${COMPOSE_PROJECT_NAME:-$(basename "$RAIZ" | tr '[:upper:]' '[:lower:]')}"
  export PATH="$FLUTTER_DIR/bin:$PATH"

  if [[ $EUID -eq 0 ]]; then
    erro "Não execute como root: rode com o seu usuário (ex.: opc), que tem sudo.
     O Docker continua rodando como serviço do sistema; o script dá ao seu usuário
     acesso a ele (grupo docker) e usa sudo apenas onde é necessário.

     1) Saia do root até o prompt mostrar o seu usuário:   exit
     2) Clone o projeto na sua pasta e execute:
          git clone https://github.com/caiovlage/gestao-bar.git ~/gestao-bar
          cd ~/gestao-bar && ./deploy.sh"
  fi
  command -v dnf >/dev/null || erro "Este script é para Oracle Linux 8/9 (dnf não encontrado)."
  sudo -v || erro "É necessário acesso sudo."
  USER="${USER:-$(id -un)}"

  titulo "Gestão do Bar — deploy ($(date '+%d/%m/%Y %H:%M'))"

  # Arquivos do projeto criados como root (clone ou comandos com sudo) impedem git e builds.
  garantir_dono "$RAIZ" "pasta do projeto"

  # ================================================================== 1. pré-requisitos
  passo "Pré-requisitos do sistema"
  instalar_pacotes git curl unzip xz which tar zip rsync openssl dnf-plugins-core \
                   policycoreutils-python-utils nginx

  if ! command -v docker >/dev/null; then
    info "Instalando Docker CE"
    sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
    sudo sed -i "s/\$releasever/$(rpm -E %rhel)/g" /etc/yum.repos.d/docker-ce.repo
    sudo dnf install -y --allowerasing docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin
  fi
  # Também quando o Docker já foi instalado antes (por exemplo, pelo root).
  if ! id -nG "$USER" | grep -qw docker; then
    sudo usermod -aG docker "$USER"
    info "Usuário $USER adicionado ao grupo docker (vale a partir do próximo login)"
  fi
  sudo systemctl enable -q --now docker
  # Sem precisar sair e entrar de novo na sessão: usa sudo enquanto o grupo docker não valer.
  local DOCKER=(docker)
  docker info >/dev/null 2>&1 || DOCKER=(sudo docker)
  ok "Docker $("${DOCKER[@]}" version --format '{{.Server.Version}}')"

  if [[ $PAINEL -eq 1 ]]; then
    if [[ ! -x "$FLUTTER_DIR/bin/flutter" ]]; then
      info "Instalando Flutter em $FLUTTER_DIR (alguns minutos)"
      sudo git clone -b stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
      sudo chown -R "$USER": "$FLUTTER_DIR"
      grep -q "$FLUTTER_DIR/bin" ~/.bashrc 2>/dev/null || echo "export PATH=\"$FLUTTER_DIR/bin:\$PATH\"" >> ~/.bashrc
      flutter config --no-analytics --no-enable-android --enable-web >/dev/null
    fi
    # Flutter instalado ou executado antes como root não consegue atualizar o próprio cache.
    garantir_dono "$FLUTTER_DIR" "Flutter"
    local VERSAO_FLUTTER; VERSAO_FLUTTER="$(flutter --version 2>/dev/null | awk '/^Flutter/{print $2; exit}')"
    if ! versao_maior_igual "$VERSAO_FLUTTER" "$FLUTTER_MIN"; then
      info "Flutter $VERSAO_FLUTTER é anterior a $FLUTTER_MIN; atualizando"
      flutter upgrade
      VERSAO_FLUTTER="$(flutter --version 2>/dev/null | awk '/^Flutter/{print $2; exit}')"
    fi
    ok "Flutter $VERSAO_FLUTTER"
  fi

  # ================================================================== 2. código
  if [[ $PULL -eq 1 ]]; then
    passo "Código (origin/$BRANCH)"
    local HASH_ANTES; HASH_ANTES="$(sha1sum "$RAIZ/deploy.sh")"
    git fetch -q origin "$BRANCH"

    if [[ $FORCAR -eq 1 ]]; then
      local ALTERACOES NOVOS
      ALTERACOES="$(git status --short --untracked-files=no)"
      NOVOS="$(git log --oneline "HEAD..origin/$BRANCH" 2>/dev/null || true)"
      [[ -n "$ALTERACOES" ]] && { aviso "Alterações locais que serão DESCARTADAS:"; echo "$ALTERACOES" | sed 's/^/     /'; }
      [[ -n "$NOVOS" ]] && { info "Commits novos:"; echo "$NOVOS" | sed 's/^/     /'; }
      if [[ $CONFIRMAR -eq 1 ]]; then
        read -rp "   Igualar o código ao GitHub e reinstalar? [s/N] " resposta
        [[ "$resposta" =~ ^[sS]$ ]] || { echo "   Cancelado."; exit 0; }
      fi
      git checkout -q "$BRANCH" 2>/dev/null || git checkout -q -b "$BRANCH" "origin/$BRANCH"
      git reset -q --hard "origin/$BRANCH"
    else
      if ! git pull -q --ff-only origin "$BRANCH"; then
        erro "Não foi possível atualizar o código (alterações locais ou histórico divergente).
     Para descartar as alterações do servidor e usar a versão do GitHub: ./deploy.sh --forcar"
      fi
    fi
    ok "Versão: $(git log -1 --format='%h %s (%cd)' --date=format:'%d/%m %H:%M')"

    # Se este próprio script mudou, reinicia com a versão nova (sem baixar de novo).
    if [[ "$(sha1sum "$RAIZ/deploy.sh")" != "$HASH_ANTES" ]]; then
      info "O deploy.sh foi atualizado; reiniciando com a versão nova"
      local REPASSAR=() a
      for a in "${ARGS_ORIGINAIS[@]}"; do
        [[ "$a" == "--forcar" || "$a" == "--sem-pull" ]] || REPASSAR+=("$a")
      done
      exec "$RAIZ/deploy.sh" --sem-pull "${REPASSAR[@]}"
    fi
  fi

  # ================================================================== 3. .env
  passo "Configuração (.env)"
  local SENHA_ADMIN_GERADA=""
  if [[ ! -f .env ]]; then
    if "${DOCKER[@]}" volume inspect "${PROJETO}_pgdata" >/dev/null 2>&1; then
      erro "O arquivo .env não existe, mas o banco (${PROJETO}_pgdata) já existe.
     Recupere o .env original (as senhas do banco estão nele) em vez de gerar um novo."
    fi
    SENHA_ADMIN_GERADA="$(openssl rand -hex 8)"
    cp .env.example .env
    chmod 600 .env
    definir_env POSTGRES_PASSWORD "$(openssl rand -hex 24)"
    definir_env JWT_SECRET "$(openssl rand -hex 32)"
    definir_env ADMIN_LOGIN admin
    definir_env ADMIN_PASSWORD "$SENHA_ADMIN_GERADA"
    definir_env SWAGGER_ENABLED false
    ok ".env criado com senhas aleatórias"
  else
    ok ".env existente mantido"
  fi

  # ================================================================== 4. nginx
  passo "nginx (porta 80)"
  if [[ ! -d "$WEB_DIR" || ! -w "$WEB_DIR" || ! -d "$CARDAPIO_DIR" || ! -w "$CARDAPIO_DIR" ]]; then
    sudo mkdir -p "$WEB_DIR" "$CARDAPIO_DIR"
    sudo chown -R "$USER": /var/www/gestao-bar
    sudo chmod 755 /var/www /var/www/gestao-bar
  fi

  if [[ ! -f "$NGINX_CONF" ]]; then
    sudo cp infra/nginx/gestao-bar.conf "$NGINX_CONF"
    # O site de boas-vindas do nginx.conf não pode ser o site padrão da porta 80.
    [[ -f /etc/nginx/nginx.conf.antes-gestao-bar ]] || sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.antes-gestao-bar
    sudo sed -i 's/ default_server//' /etc/nginx/nginx.conf
    ok "Configuração instalada em $NGINX_CONF"
  elif ! sudo grep -q 'location /cardapio/' "$NGINX_CONF"; then
    # Instalação anterior à Etapa 6: acrescenta o cardápio sem tocar no resto (server_name/HTTPS).
    info "Adicionando o cardápio digital (/cardapio/) à configuração do nginx"
    sudo cp "$NGINX_CONF" "$NGINX_CONF.antes-cardapio"
    if sudo grep -q 'location = / ' "$NGINX_CONF"; then
      sudo awk -v trecho="$(cat infra/nginx/cardapio.location)" \
          '!feito && /location = \/ /{print trecho; feito=1} {print}' "$NGINX_CONF.antes-cardapio" \
          | sudo tee "$NGINX_CONF" >/dev/null
      if sudo nginx -t -q 2>/dev/null; then
        ok "Cardápio adicionado (cópia anterior: $NGINX_CONF.antes-cardapio)"
      else
        sudo cp "$NGINX_CONF.antes-cardapio" "$NGINX_CONF"
        aviso "Não foi possível adicionar o cardápio automaticamente; configuração anterior restaurada."
        aviso "Copie manualmente o bloco de infra/nginx/cardapio.location para $NGINX_CONF."
      fi
    else
      aviso "Não encontrei 'location = /' em $NGINX_CONF. Copie manualmente o bloco de"
      aviso "infra/nginx/cardapio.location para dentro do bloco server da porta 80/443."
    fi
  elif ! sudo diff -q infra/nginx/gestao-bar.conf "$NGINX_CONF" >/dev/null 2>&1; then
    aviso "A configuração do nginx do repositório difere da instalada (mantida a instalada,"
    aviso "pois pode ter server_name/HTTPS). Compare: sudo diff infra/nginx/gestao-bar.conf $NGINX_CONF"
  fi

  if command -v selinuxenabled >/dev/null && selinuxenabled; then
    if ! getsebool httpd_can_network_connect | grep -q ' on$'; then
      info "SELinux: permitindo que o nginx acesse o backend"
      sudo setsebool -P httpd_can_network_connect 1
    fi
  fi

  if systemctl is-active --quiet firewalld; then
    if ! sudo firewall-cmd --list-services | grep -qw http; then
      sudo firewall-cmd -q --permanent --add-service=http
      sudo firewall-cmd -q --reload
      ok "Firewall: porta 80 liberada"
    fi
  fi

  sudo nginx -t -q || erro "Configuração do nginx inválida (veja a mensagem acima)."

  # nginx iniciado manualmente (ex.: "sudo nginx") ocupa a porta 80 fora do systemd e
  # impede o serviço de iniciar. Encerra essa instância para o systemd assumir.
  if ! systemctl is-active --quiet nginx && pgrep -x nginx >/dev/null; then
    aviso "nginx rodando fora do systemd (iniciado manualmente); reiniciando pelo systemd"
    sudo nginx -s quit 2>/dev/null || sudo pkill -x nginx || true
    sleep 2
  fi
  if systemctl is-active --quiet nginx; then
    sudo systemctl reload nginx
  else
    sudo systemctl reset-failed nginx 2>/dev/null || true
    if ! sudo systemctl start nginx; then
      sudo journalctl -u nginx -n 15 --no-pager >&2 || true
      erro "O nginx não iniciou (detalhes acima). Verifique se outro programa usa a porta 80: sudo ss -ltnp 'sport = :80'"
    fi
  fi
  sudo systemctl enable -q nginx
  ok "nginx ativo"

  # ================================================================== 5. banco de dados
  passo "Banco de dados (PostgreSQL no Docker)"
  local BANCO_EXISTIA=0
  "${DOCKER[@]}" volume inspect "${PROJETO}_pgdata" >/dev/null 2>&1 && BANCO_EXISTIA=1
  "${DOCKER[@]}" compose up -d postgres
  local limite_bd=$((SECONDS + 120))
  until "${DOCKER[@]}" compose exec -T postgres sh -c 'pg_isready -q -U "$POSTGRES_USER" -d "$POSTGRES_DB"' 2>/dev/null; do
    if (( SECONDS > limite_bd )); then
      "${DOCKER[@]}" compose logs --tail 30 postgres || true
      erro "O banco não ficou pronto em 2 minutos (logs acima)."
    fi
    sleep 2
  done
  if [[ $BANCO_EXISTIA -eq 1 ]]; then ok "Banco no ar (dados existentes mantidos)"; else ok "Banco criado e no ar"; fi

  # Backup antes de qualquer atualização (as migrations podem alterar o banco).
  if [[ $BACKUP -eq 1 && $BANCO_EXISTIA -eq 1 ]]; then
    mkdir -p "$HOME/backups"
    local ARQUIVO; ARQUIVO="$HOME/backups/gestao-bar-$(date +%F-%H%M%S).sql.gz"
    "${DOCKER[@]}" compose exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' | gzip > "$ARQUIVO"
    ok "Backup: $ARQUIVO ($(du -h "$ARQUIVO" | cut -f1))"
  fi

  # ================================================================== 6. frontend (painel e cardápio)
  if [[ $PAINEL -eq 1 ]]; then
    passo "Frontend: painel e cardápio digital"
    if [[ ! -d frontend/apps/admin/web ]]; then
      (cd frontend/apps/admin && flutter create . --platforms=web --project-name gestao_bar_admin --no-pub >/dev/null)
    fi
    if [[ ! -d frontend/apps/cardapio/web ]]; then
      (cd frontend/apps/cardapio && flutter create . --platforms=web --project-name gestao_bar_cardapio --no-pub >/dev/null)
    fi
    # Página inicial otimizada para celular (tela de carregamento imediata, cores, ícone na tela inicial)
    cp frontend/apps/cardapio/web_modelo/index.html frontend/apps/cardapio/web/index.html
    sed -i 's/"name": *"[^"]*"/"name": "Cardápio"/; s/"short_name": *"[^"]*"/"short_name": "Cardápio"/; s/"background_color": *"[^"]*"/"background_color": "#0E0C0A"/; s/"theme_color": *"[^"]*"/"theme_color": "#0E0C0A"/'         frontend/apps/cardapio/web/manifest.json
    if [[ $LIMPO -eq 1 ]]; then
      (cd frontend/apps/admin && flutter clean >/dev/null)
      (cd frontend/apps/cardapio && flutter clean >/dev/null)
    fi
    (cd frontend && flutter pub get >/dev/null)
    # Sem API_URL: os apps chamam a API na mesma origem (http://SERVIDOR/api/), via nginx na porta 80.
    info "Compilando o painel (/admin/)"
    (cd frontend/apps/admin && flutter build web --release --base-href /admin/)
    info "Compilando o cardápio (/cardapio/)"
    # --no-web-resources-cdn: o motor gráfico do Flutter sai do próprio servidor, sem depender do CDN do Google
    (cd frontend/apps/cardapio && flutter build web --release --base-href /cardapio/ --no-web-resources-cdn)
    rsync -a --delete frontend/apps/admin/build/web/ "$WEB_DIR/"
    rsync -a --delete frontend/apps/cardapio/build/web/ "$CARDAPIO_DIR/"
    if command -v restorecon >/dev/null; then sudo restorecon -R /var/www/gestao-bar; fi
    ok "Publicado em $WEB_DIR e $CARDAPIO_DIR"
  fi

  # ================================================================== 7. backend
  if [[ $BACKEND -eq 1 ]]; then
    passo "Backend (Docker)"
    [[ $LIMPO -eq 0 ]] || "${DOCKER[@]}" compose --profile full build --no-cache --pull backend
    "${DOCKER[@]}" compose --profile full up -d --build --remove-orphans

    info "Aguardando o backend iniciar (a primeira vez pode levar alguns minutos)"
    local limite=$((SECONDS + 300))
    until curl -fs http://127.0.0.1:8080/actuator/health 2>/dev/null | grep -q '"UP"'; do
      if (( SECONDS > limite )); then
        "${DOCKER[@]}" compose logs --tail 40 backend || true
        erro "O backend não ficou pronto em 5 minutos (logs acima)."
      fi
      sleep 5
    done
    ok "Backend no ar"
  fi

  # ================================================================== 7b. backup diário no Git
  passo "Backup diário no Git (agendamento)"
  # A chave fica só no servidor (.backup-git/ está no .gitignore). Ligar, desligar e escolher o
  # repositório é feito no painel: Configurações → Backup diário no Git.
  local BKP="$RAIZ/.backup-git"
  mkdir -p "$BKP"
  chmod 700 "$BKP"
  if [[ ! -f "$BKP/id_ed25519" ]]; then
    ssh-keygen -q -t ed25519 -N "" -C "gestao-bar-backup@$(hostname -s)" -f "$BKP/id_ed25519"
    ok "Chave SSH do backup criada"
  fi
  chmod +x infra/backup/backup-git.sh
  sudo tee /etc/systemd/system/gestao-bar-backup.service >/dev/null <<UNIDADE
[Unit]
Description=Gestão do Bar - backup diário do banco no Git (se ligado no painel)
After=docker.service
Wants=docker.service

[Service]
Type=oneshot
User=$USER
WorkingDirectory=$RAIZ
ExecStart=$RAIZ/infra/backup/backup-git.sh
UNIDADE
  sudo tee /etc/systemd/system/gestao-bar-backup.timer >/dev/null <<UNIDADE
[Unit]
Description=Verifica a cada 5 minutos se é hora do backup no Git

[Timer]
OnBootSec=3min
OnCalendar=*:0/5
AccuracySec=30s

[Install]
WantedBy=timers.target
UNIDADE
  sudo systemctl daemon-reload
  sudo systemctl enable --now -q gestao-bar-backup.timer
  ok "Verificação de backup agendada (a cada 5 min; o envio segue as Configurações do painel)"
  info "Chave pública para cadastrar no repositório privado (Deploy keys, com escrita):"
  info "$(cat "$BKP/id_ed25519.pub")"

  # ================================================================== 8. verificação
  passo "Verificação pela porta 80"
  local falhas=0
  verificar "Painel  http://localhost/admin/" "$(codigo_http http://127.0.0.1/admin/)" 200 || falhas=1
  verificar "Cardápio http://localhost/cardapio/" "$(codigo_http http://127.0.0.1/cardapio/)" 200 || falhas=1
  verificar "API     http://localhost/api/   " "$(codigo_http http://127.0.0.1/api/admin/produtos)" 401 || falhas=1
  local MIGRATIONS
  MIGRATIONS="$("${DOCKER[@]}" compose exec -T postgres sh -c \
      'psql -tAq -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "select count(*) from flyway_schema_history where success"' \
      2>/dev/null | tr -d '[:space:]' || true)"
  if [[ "$MIGRATIONS" =~ ^[0-9]+$ && "$MIGRATIONS" -gt 0 ]]; then
    ok "Banco   PostgreSQL               → $MIGRATIONS migration(s) aplicada(s)"
  else
    aviso "Banco   PostgreSQL               → migrations não encontradas (o backend iniciou?)"
    falhas=1
  fi

  local IP; IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
  titulo "Concluído"
  echo "   Acesse: http://${IP:-SERVIDOR}/   (painel em /admin/, API em /api/)"
  echo "   Cardápio do cliente: http://${IP:-SERVIDOR}/cardapio/   (QR Codes das mesas em Configurações)"
  if [[ -n "$SENHA_ADMIN_GERADA" ]]; then
    echo
    echo "   Login inicial do painel:  admin  /  $SENHA_ADMIN_GERADA"
    echo "   (guardado em $RAIZ/.env — para trocar, edite ADMIN_PASSWORD e rode ./deploy.sh --so-backend)"
  fi
  if [[ $falhas -ne 0 ]]; then
    aviso "Alguma verificação falhou: veja 'Problemas comuns' em docs/instalacao.md."
    exit 1
  fi
}

# ---------------------------------------------------------------------- auxiliares
titulo() { printf '\n\033[1;33m== %s ==\033[0m\n' "$1"; }
passo()  { printf '\n\033[1m>> %s\033[0m\n' "$1"; }
ok()     { printf '   \033[32m✔\033[0m %s\n' "$1"; }
info()   { printf '   • %s\n' "$1"; }
aviso()  { printf '   \033[33m!\033[0m %s\n' "$1"; }
erro()   { printf '\n\033[31m✘ %s\033[0m\n' "$1" >&2; exit 1; }

instalar_pacotes() {
  local faltando=()
  for p in "$@"; do rpm -q "$p" >/dev/null 2>&1 || faltando+=("$p"); done
  if [[ ${#faltando[@]} -gt 0 ]]; then
    info "Instalando: ${faltando[*]}"
    sudo dnf install -y "${faltando[@]}"
  fi
  ok "Pacotes do sistema"
}

# Substitui CHAVE=valor no .env (valores gerados são hexadecimais, seguros para o sed).
definir_env() {
  if grep -q "^$1=" .env; then sed -i "s|^$1=.*|$1=$2|" .env; else echo "$1=$2" >> .env; fi
}

# Se houver arquivos em $1 que não pertencem ao usuário atual, devolve a posse a ele.
garantir_dono() {
  [[ -d "$1" ]] || return 0
  local alheio; alheio="$(sudo find "$1" ! -user "$USER" -print -quit 2>/dev/null)"
  if [[ -n "$alheio" ]]; then
    info "Corrigindo dono dos arquivos de $2 ($1) para $USER (havia arquivos de outro usuário, ex.: root)"
    sudo chown -R "$USER": "$1"
  fi
}

versao_maior_igual() {
  [[ -n "$1" ]] && [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" == "$2" ]]
}

codigo_http() { curl -s -o /dev/null -w '%{http_code}' "$1" || echo "000"; }

verificar() {
  if [[ "$2" == "$3" ]]; then ok "$1 → $2"; else aviso "$1 → $2 (esperado $3)"; return 1; fi
}

main "$@"
exit
