# Instalação no Oracle Linux

Guia para instalar o sistema em um servidor **Oracle Linux 8 ou 9** (x86_64 ou ARM/aarch64,
incluindo instâncias da Oracle Cloud). Tudo roda em contêineres Docker:

```
Navegador / APK ──► nginx :80 ──┬── /admin/  → painel Flutter (arquivos estáticos)
                                └── /api/    → backend Spring Boot :8080 ──► PostgreSQL :5432
```

O backend e o banco ficam acessíveis **somente pelo próprio servidor** (127.0.0.1). Para fora, só o nginx fica exposto.

## Requisitos

| Item | Mínimo |
|---|---|
| Sistema | Oracle Linux 8 ou 9 |
| Memória | 2 GB (4 GB recomendados: a compilação do backend e do Flutter usa bastante memória) |
| Disco | 10 GB livres |
| Acesso | usuário com `sudo` e acesso à internet (para baixar imagens e dependências) |

Todos os comandos abaixo são executados como um usuário comum com `sudo`, **não** como root.

---

## 1. Pacotes básicos

```bash
sudo dnf install -y git curl unzip xz which tar zip dnf-plugins-core
```

## 2. Docker

O Oracle Linux traz o Podman por padrão; o projeto usa o Docker CE com o plugin `docker compose`.

```bash
# Repositório oficial do Docker (RHEL), fixando a versão principal do sistema (8 ou 9)
sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
sudo sed -i "s/\$releasever/$(rpm -E %rhel)/g" /etc/yum.repos.d/docker-ce.repo

# --allowerasing substitui pacotes do Podman que conflitam com o Docker
sudo dnf install -y --allowerasing docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin

sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
```

**Saia e entre novamente na sessão SSH** para o grupo `docker` valer. Confira:

```bash
docker run --rm hello-world
docker compose version
```

## 3. Código do projeto

```bash
cd ~
git clone https://github.com/caiovlage/gestao-bar.git gestao-bar
cd ~/gestao-bar
```

Sem repositório Git, copie a pasta do projeto a partir do seu computador:

```bash
# executar no seu computador (não no servidor)
scp -r pdv usuario@IP-DO-SERVIDOR:~/gestao-bar
```

## 4. Variáveis de ambiente

```bash
cd ~/gestao-bar
cp .env.example .env
chmod 600 .env
```

Gere valores seguros:

```bash
openssl rand -base64 48   # use como JWT_SECRET
openssl rand -base64 24   # use como POSTGRES_PASSWORD
openssl rand -base64 18   # use como ADMIN_PASSWORD (ou escolha uma senha forte)
```

Edite o arquivo (`nano .env` ou `vi .env`) e preencha:

| Variável | Valor |
|---|---|
| `POSTGRES_PASSWORD` | senha do banco gerada acima |
| `ADMIN_LOGIN` | login do painel (ex.: `admin`) |
| `ADMIN_PASSWORD` | senha do painel (mínimo 8 caracteres) |
| `JWT_SECRET` | segredo gerado acima (mínimo 32 caracteres) |
| `SWAGGER_ENABLED` | `false` em produção |

A senha do administrador é gravada apenas como hash BCrypt. Para trocá-la depois, altere
`ADMIN_PASSWORD` e reinicie o backend (passo 9).

## 5. Flutter (para gerar o painel web)

> **Alternativa:** se preferir não instalar o Flutter no servidor, gere o painel no seu computador
> (comando do passo 6) e copie a pasta `frontend/apps/admin/build/web` para o mesmo caminho no servidor.
> Nesse caso, pule para o passo 7.

```bash
sudo git clone -b stable https://github.com/flutter/flutter.git /opt/flutter
sudo chown -R "$USER": /opt/flutter
echo 'export PATH="/opt/flutter/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

flutter config --no-analytics --no-enable-android --enable-web
flutter precache --web
flutter --version        # precisa ser 3.47 ou superior
```

Não use `git clone --depth 1`: sem o histórico, o Flutter não identifica a própria versão e o build falha.

## 6. Gerar o painel web

```bash
cd ~/gestao-bar/frontend/apps/admin
flutter create . --platforms=web --project-name gestao_bar_admin --no-pub   # apenas na primeira vez
cd ~/gestao-bar/frontend
flutter pub get

cd apps/admin
flutter build web --release --base-href /admin/ --dart-define=API_URL=
```

`API_URL` vazio faz o painel chamar a API no mesmo endereço do site. O nginx encaminha `/api` ao backend.

## 7. Subir o sistema

```bash
cd ~/gestao-bar
docker compose --profile full up -d --build
```

A primeira execução compila o backend dentro do contêiner e leva alguns minutos.
Acompanhe até aparecer `Started GestaoBarApplication`:

```bash
docker compose logs -f backend
```

## 8. Firewall e acesso externo

### firewalld (no servidor)

```bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload
```

### Oracle Cloud (OCI)

Se o servidor for uma instância da Oracle Cloud, libere também a porta na nuvem:
**Networking → Virtual Cloud Networks → (sua VCN) → Security Lists → Add Ingress Rules**
com origem `0.0.0.0/0`, protocolo TCP e porta de destino `80`.

### SELinux

O Oracle Linux vem com SELinux ativo (`getenforce` mostra `Enforcing`). Não é preciso desativá-lo:
o `docker-compose.yml` já usa a opção `:z` nos arquivos montados no nginx.

## 9. Verificação

```bash
docker compose ps                                     # todos os serviços "running"/"healthy"
curl -s http://127.0.0.1:8080/actuator/health         # {"status":"UP"}
curl -sI http://localhost/admin/ | head -1            # HTTP/1.1 200 OK
```

No navegador: **http://IP-DO-SERVIDOR/admin/**. Entre com `ADMIN_LOGIN` / `ADMIN_PASSWORD`.

> **HTTPS:** com HTTP simples, login e dados trafegam sem criptografia. Antes de expor o sistema na internet,
> configure um domínio e um certificado TLS (ex.: Let's Encrypt) no nginx. Na rede interna do bar, HTTP é aceitável.

---

## Operação do dia a dia

| Tarefa | Comando (em `~/gestao-bar`) |
|---|---|
| Ver status | `docker compose ps` |
| Ver logs do backend | `docker compose logs -f backend` |
| Reiniciar o backend (ex.: após mudar o `.env`) | `docker compose --profile full up -d backend` |
| Parar tudo | `docker compose --profile full down` |
| Iniciar tudo | `docker compose --profile full up -d` |

Os serviços usam `restart: unless-stopped` e voltam sozinhos após reiniciar o servidor.

### Atualizar para uma nova versão

```bash
cd ~/gestao-bar
git pull
cd frontend && flutter pub get && cd apps/admin
flutter build web --release --base-href /admin/ --dart-define=API_URL=
cd ~/gestao-bar
docker compose --profile full up -d --build
```

As migrations do banco são aplicadas automaticamente pelo Flyway na inicialização do backend.

### Backup do banco

```bash
mkdir -p ~/backups
docker compose exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' \
    | gzip > ~/backups/gestao-bar-$(date +%F).sql.gz
```

Backup diário automático às 3h (cron):

```bash
(crontab -l 2>/dev/null; echo "0 3 * * * cd $HOME/gestao-bar && docker compose exec -T postgres sh -c 'pg_dump -U \"\$POSTGRES_USER\" \"\$POSTGRES_DB\"' | gzip > $HOME/backups/gestao-bar-\$(date +\%F).sql.gz") | crontab -
```

As imagens dos produtos ficam no volume Docker `gestao-bar_uploads`. Para copiá-las:

```bash
docker run --rm -v gestao-bar_uploads:/dados -v ~/backups:/backup alpine \
    tar czf /backup/uploads-$(date +%F).tar.gz -C /dados .
```

### Restaurar um backup

```bash
gunzip -c ~/backups/gestao-bar-AAAA-MM-DD.sql.gz | \
    docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" "$POSTGRES_DB"'
```

Restaure em um banco vazio (instalação nova). Para sobrescrever um banco em uso, pare o backend antes.

---

## Aplicativo Android (APK)

Para gerar o APK é preciso o Android SDK, que é pesado para um servidor. Gere o APK em um computador
de desenvolvimento com o Flutter e o Android Studio instalados:

```bash
cd frontend/apps/admin
flutter create . --platforms=android --project-name gestao_bar_admin --no-pub   # apenas na primeira vez
flutter build apk --release --dart-define=API_URL=http://IP-DO-SERVIDOR
```

Enquanto o servidor usar HTTP (sem TLS), habilite em
`android/app/src/main/AndroidManifest.xml`, na tag `<application>`: `android:usesCleartextTraffic="true"`.

---

## Desenvolvimento (opcional)

Para rodar o backend fora do Docker, por exemplo no Oracle Linux ou em outra máquina de desenvolvimento:

```bash
sudo dnf install -y java-21-openjdk-devel     # Oracle Linux
docker compose up -d postgres                 # só o banco
cd backend
./gradlew bootRun                             # lê ../.env automaticamente
./gradlew test                                # testes (os de integração exigem Docker)
```

Em desenvolvimento, use `SWAGGER_ENABLED=true` no `.env` para acessar http://localhost:8080/swagger-ui.html.
Para o painel, rode `flutter run -d chrome --dart-define=API_URL=http://localhost:8080` em `frontend/apps/admin`.
No Windows, o Docker Desktop substitui os passos 1 e 2, e o Gradle baixa o JDK 21 automaticamente.
