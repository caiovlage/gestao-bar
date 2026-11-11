# Instalação no Oracle Linux

Guia para instalar o sistema em um servidor **Oracle Linux 8 ou 9** (x86_64 ou ARM/aarch64,
incluindo instâncias da Oracle Cloud).

```
                        ┌──────────── servidor Oracle Linux ─────────────────────────┐
Navegador / APK ──:80──►│ nginx (instalado no Linux)                                 │
                        │   /admin/ → /var/www/gestao-bar/admin  (painel Flutter)    │
                        │   /api/   → 127.0.0.1:8080 ──► backend (Docker)            │
                        │                                   └──► PostgreSQL (Docker) │
                        └────────────────────────────────────────────────────────────┘
```

Tudo sai pela **porta 80**: `http://SERVIDOR/` abre o **cardápio** do cliente (`/cardapio/`), o painel fica em
`http://SERVIDOR/admin/` e a API em `http://SERVIDOR/api/`.
O backend (8080) e o banco (5432) ficam acessíveis **somente dentro do servidor**.

**Só a porta 80 precisa estar aberta.** O navegador baixa o painel pela porta 80 e o painel chama a
API no mesmo endereço e porta de onde foi carregado (`http://SERVIDOR/api/...`); o nginx repassa
internamente ao backend. Não abra as portas 8080 nem 5432 no firewall ou na Oracle Cloud.
Funciona com qualquer IP ou domínio, sem gerar o painel de novo.

## Requisitos

| Item | Mínimo |
|---|---|
| Sistema | Oracle Linux 8 ou 9 |
| Memória | 2 GB (4 GB recomendados: a compilação do backend e do Flutter usa bastante memória) |
| Disco | 10 GB livres |
| Acesso | usuário comum com `sudo` (não root) e acesso à internet |

---

## Instalação

```bash
sudo dnf install -y git
git clone https://github.com/caiovlage/gestao-bar.git ~/gestao-bar
cd ~/gestao-bar
./deploy.sh
```

A primeira execução leva de 10 a 20 minutos. Ao final, o script mostra o endereço de acesso e
o **login inicial do painel** (`admin` e uma senha gerada, guardada em `~/gestao-bar/.env`).

### O que o `deploy.sh` faz

| Etapa | Primeira execução | Execuções seguintes |
|---|---|---|
| Pré-requisitos | instala pacotes, nginx, Docker e Flutter | confere (nada a fazer) |
| Código | — | `git pull` da branch `main` |
| `.env` | cria com senhas aleatórias (banco, JWT, admin) | mantém o existente |
| nginx | instala `infra/nginx/gestao-bar.conf`, ajusta SELinux e firewall | mantém a configuração instalada |
| Banco de dados | cria e sobe o PostgreSQL | sobe o PostgreSQL e faz **backup** em `~/backups` |
| Painel (frontend) | gera o Flutter Web e publica em `/var/www/gestao-bar/admin` | idem |
| Backend | compila e sobe no Docker; as migrations criam as tabelas | recompila, sobe e aplica migrations novas |
| Verificação | testa painel, API e banco pela porta 80 | idem |

O script pode ser executado quantas vezes quiser; cada etapa só age quando necessário.

### Oracle Cloud (OCI)

Se o servidor for uma instância da Oracle Cloud, libere a porta também na nuvem (o script não
tem acesso a isso): **Networking → Virtual Cloud Networks → (sua VCN) → Security Lists →
Add Ingress Rules** com origem `0.0.0.0/0`, protocolo TCP e porta de destino `80`.

---

## Atualizar

Depois de enviar alterações ao GitHub, no servidor:

```bash
cd ~/gestao-bar
./deploy.sh
```

| Comando | Quando usar |
|---|---|
| `./deploy.sh` | atualização normal: código novo + banco + painel + backend |
| `./deploy.sh --forcar` | o `git pull` falhou (alterações feitas no servidor ou push forçado no GitHub): descarta as alterações locais, iguala ao GitHub e reinstala tudo. Mostra o que será descartado e pede confirmação (`-y` pula a confirmação) |
| `./deploy.sh --limpo` | algo estranho após atualizar: recompila tudo do zero, sem cache |
| `./deploy.sh --so-painel` | atualizar apenas o painel (frontend) |
| `./deploy.sh --so-backend` | atualizar apenas o backend (ex.: após mudar o `.env`) |
| `./deploy.sh --sem-pull` | reinstalar sem baixar código novo |
| `./deploy.sh --help` | todas as opções |

Sempre preservados: `.env`, banco de dados, imagens dos produtos, configuração do nginx em `/etc/nginx`
e certificados HTTPS. Antes de atualizar, o script faz backup do banco em `~/backups`.

### Trocar a senha do painel

Edite `ADMIN_PASSWORD` em `~/gestao-bar/.env` (mínimo 8 caracteres) e rode `./deploy.sh --so-backend --sem-pull`.

### Configuração do nginx

O script instala `infra/nginx/gestao-bar.conf` apenas na primeira vez e depois **não sobrescreve**
`/etc/nginx/conf.d/gestao-bar.conf` (ele pode conter seu domínio e o HTTPS). Se o arquivo do
repositório mudar, o script avisa; compare e aplique manualmente:

```bash
sudo diff ~/gestao-bar/infra/nginx/gestao-bar.conf /etc/nginx/conf.d/gestao-bar.conf
sudo nginx -t && sudo systemctl reload nginx
```

Exceção: em instalações anteriores à Etapa 6, o script **acrescenta sozinho** o bloco do cardápio
(`location /cardapio/`, em `infra/nginx/cardapio.location`) e guarda a versão anterior em
`/etc/nginx/conf.d/gestao-bar.conf.antes-cardapio`.

### Cardápio digital (pedidos para entrega)

- Endereço para o cliente: `http://SERVIDOR/` (redireciona para `/cardapio/`; o mesmo nginx, porta 80).
- Em **Configurações → Cardápio digital**, use **Compartilhar no WhatsApp** (ou copie o link) para
  enviar aos moradores. O cliente abre no navegador do celular, escolhe os produtos e informa
  **nome, bloco e apartamento**; o celular lembra esses dados para o próximo pedido. Há também um
  QR Code único para cartazes (elevador, portaria).
- Só aparecem no cardápio produtos marcados **"Disponível no cardápio digital"**, com preço, de
  categorias visíveis no cardápio. Desligue **"Cardápio aberto para pedidos"** para pausar os
  pedidos (ex.: sem entregadores).
- **Prévia do link**: ao colar o link no WhatsApp aparece a imagem da marca. O WhatsApp guarda a prévia
  por alguns dias: se colou o link antes da atualização, a imagem nova pode demorar a aparecer
  (teste com `http://SERVIDOR/cardapio/?v=2`).
- **Notificações de novos pedidos** (precisa de HTTPS): em cada celular ou notebook da equipe, abra o
  painel pelo `https://` e toque em **Ativar neste aparelho** (Configurações ou sino em Pedidos); o
  navegador pergunta se permite notificações. No **iPhone**, primeiro adicione o painel à Tela de Início
  (Compartilhar → Adicionar à Tela de Início) e ative pelo ícone. Use **Enviar teste** para conferir.
- **Vitrine** (Configurações → Vitrine do cardápio): escolha as seções de destaque do topo do cardápio
  (Sugestões da casa, Promoções, Mais pedidos, Menos pedidos, Novidades), a ordem, os títulos e a
  quantidade. Promoções e sugestões são definidas no cadastro de cada produto.
- Os pedidos chegam em **Pedidos** (atualiza a cada 10 s) com bloco e apartamento: aceitar (reserva o
  estoque), preparar, marcar pronto/entregue e **Concluir venda** na entrega (gera a venda no caixa aberto).
- O cardápio funciona sem HTTPS. Com domínio e HTTPS, compartilhe o link de novo acessando o painel
  pelo endereço `https://` (o link usa o endereço do painel).

---

## Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| Página "Welcome to nginx" | site padrão do `nginx.conf` ativo | `sudo sed -i 's/ default_server//' /etc/nginx/nginx.conf && sudo systemctl reload nginx` |
| `502 Bad Gateway` em `/api/` | backend parado ou SELinux bloqueando | `docker compose logs backend`; `sudo setsebool -P httpd_can_network_connect 1` |
| `403 Forbidden` em `/admin/` | rótulo SELinux ou permissão da pasta | `sudo restorecon -Rv /var/www/gestao-bar` |
| `404` em `/admin/` | painel não publicado | `./deploy.sh --so-painel --sem-pull` |
| Abre no servidor, mas não de fora | firewall ou Security List da OCI | `sudo firewall-cmd --list-services` deve conter `http`; regra da OCI acima |
| "git pull falhou" no deploy | alterações locais no servidor | `./deploy.sh --forcar` |
| "O .env não existe, mas o banco já existe" | `.env` apagado | recupere o `.env` original: as senhas do banco estão nele |
| Erro de memória ao compilar | servidor com pouca RAM | crie swap de 2 GB (`sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile`) |

Diagnóstico:

```bash
docker compose ps                         # postgres e backend
docker compose logs -f backend            # logs do backend
systemctl status nginx
sudo tail -f /var/log/nginx/error.log     # logs do nginx
```

---

## HTTPS (recomendado para acesso pela internet)

> O leitor de código de barras/QR Code pela **câmera do navegador** também exige HTTPS. Sem HTTPS, use o
> aplicativo Android ou um leitor de código de barras USB (funciona como teclado).

Com HTTP simples, login e dados trafegam sem criptografia. Na rede interna do bar é aceitável;
para acesso pela internet, use HTTPS. É necessário um **domínio** apontando (registro DNS tipo A)
para o IP do servidor.

1. Em `/etc/nginx/conf.d/gestao-bar.conf`, descomente e ajuste `server_name bar.exemplo.com.br;`
   e recarregue: `sudo nginx -t && sudo systemctl reload nginx`.
2. Libere a porta 443 (e, na OCI, crie a regra de entrada TCP 443):

   ```bash
   sudo firewall-cmd --permanent --add-service=https && sudo firewall-cmd --reload
   ```

3. Instale o certbot (repositório EPEL da Oracle) e emita o certificado:

   ```bash
   sudo dnf install -y oracle-epel-release-el$(rpm -E %rhel)
   sudo dnf install -y certbot python3-certbot-nginx
   sudo certbot --nginx -d bar.exemplo.com.br --redirect
   ```

O certbot ajusta o nginx, redireciona HTTP para HTTPS e renova o certificado automaticamente.
O painel não precisa ser gerado de novo: ele chama a API no mesmo endereço do site.

---

## Backups

O `deploy.sh` faz backup do banco antes de cada atualização. Para backups manuais ou agendados:

```bash
cd ~/gestao-bar
mkdir -p ~/backups
docker compose exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' \
    | gzip > ~/backups/gestao-bar-$(date +%F).sql.gz
```

Backup diário automático às 3h (cron):

```bash
(crontab -l 2>/dev/null; echo "0 3 * * * cd $HOME/gestao-bar && docker compose exec -T postgres sh -c 'pg_dump -U \"\$POSTGRES_USER\" \"\$POSTGRES_DB\"' | gzip > $HOME/backups/gestao-bar-\$(date +\%F).sql.gz") | crontab -
```

As imagens dos produtos ficam no volume Docker `gestao-bar_uploads`:

```bash
docker run --rm -v gestao-bar_uploads:/dados -v ~/backups:/backup alpine \
    tar czf /backup/uploads-$(date +%F).tar.gz -C /dados .
```

Guarde também uma cópia do `~/gestao-bar/.env` em local seguro: sem ele, não é possível acessar o banco.

### Backup diário no Git (repositório privado)

O servidor pode enviar uma cópia do banco por dia para um repositório Git **privado**, ligado e
desligado pelo painel em **Configurações → Backup diário no Git**.

1. No GitHub, crie um repositório **privado** vazio (ex.: `gestao-bar-backups`).
2. Rode `./deploy.sh` no servidor: ele cria a chave SSH do backup (`.backup-git/id_ed25519`, fora do
   Git) e agenda a verificação a cada 5 minutos (`gestao-bar-backup.timer`).
3. Em **Configurações → Backup diário no Git**, copie a chave do servidor. No GitHub: repositório →
   **Settings → Deploy keys → Add deploy key**, cole a chave e marque **Allow write access**.
4. No painel, informe o endereço SSH (ex.: `git@github.com:usuario/gestao-bar-backups.git`), o
   horário e quantos backups manter, ligue **Enviar backup diário** e salve.
5. Clique em **Fazer backup agora** para testar: em até 5 minutos o resultado aparece no painel.

O repositório guarda só os últimos backups (`gestao-bar-AAAA-MM-DD.sql.gz`) em um único commit, para
não crescer sem limite. A chave só tem acesso a esse repositório. Para acompanhar no servidor:

```bash
systemctl list-timers gestao-bar-backup.timer
journalctl -u gestao-bar-backup.service -n 20 --no-pager
infra/backup/backup-git.sh --agora      # envia na hora (ignora o horário)
```

### Restaurar um backup

Para usar um backup do Git, baixe o arquivo `gestao-bar-AAAA-MM-DD.sql.gz` do repositório privado
(GitHub → arquivo → *Download raw file*) para `~/backups/` e siga os comandos abaixo.

```bash
cd ~/gestao-bar
docker compose stop backend
gunzip -c ~/backups/gestao-bar-AAAA-MM-DD.sql.gz | \
    docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" "$POSTGRES_DB"'
docker compose --profile full up -d backend
```

Restaure em um banco vazio (instalação nova). Para voltar um banco em uso a um backup, apague-o antes:
`docker compose exec postgres sh -c 'dropdb -U "$POSTGRES_USER" "$POSTGRES_DB" && createdb -U "$POSTGRES_USER" "$POSTGRES_DB"'`
(com o backend parado).

---

## Aplicativo Android (APK)

Para gerar o APK é preciso o Android SDK, que é pesado para um servidor. Gere o APK em um computador
de desenvolvimento com o Flutter e o Android Studio instalados:

```bash
cd frontend/apps/admin
flutter create . --platforms=android --project-name gestao_bar_admin --no-pub   # apenas na primeira vez
flutter build apk --release --dart-define=API_URL=http://IP-OU-DOMINIO-DO-SERVIDOR
```

O app chama `API_URL` + `/api/...`, ou seja, também passa pelo nginx na porta 80 (ou 443 com HTTPS).
Enquanto o servidor usar HTTP, habilite em `android/app/src/main/AndroidManifest.xml`,
na tag `<application>`: `android:usesCleartextTraffic="true"`.

---

## Desenvolvimento (opcional)

Para rodar o backend fora do Docker numa máquina de desenvolvimento:

```bash
cp .env.example .env                          # e preencha senhas/JWT_SECRET
docker compose up -d postgres                 # só o banco
cd backend
./gradlew bootRun                             # lê ../.env automaticamente
./gradlew test                                # testes (os de integração exigem Docker)
```

Em desenvolvimento, use `SWAGGER_ENABLED=true` no `.env` para acessar http://localhost:8080/swagger-ui.html.
Para o painel, rode `flutter run -d chrome --dart-define=API_URL=http://localhost:8080` em `frontend/apps/admin`.
No Windows, use o Docker Desktop; o Gradle baixa o JDK 21 automaticamente.
