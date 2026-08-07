# Forever Love Chat local Docker deployment

This repository deploys the ASP.NET Core API, React website, and PostgreSQL to
local Docker. The API and website ports are published on `0.0.0.0` by default so
LAN devices and externally routed traffic can reach them.

## Local deploy

```powershell
.\scripts\deploy-local.ps1
```

The first run creates a shared local env file at
`%USERPROFILE%\.foreverlove-chat\foreverlove-chat.env` with generated secrets.
All checkouts and the self-hosted runner reuse that file, so the Docker database
password stays stable across deployments. Override the location with
`FOREVERLOVE_CHAT_ENV_FILE` when needed.

Uploaded avatars, chat images, and chat files should be kept outside the GitHub
Actions checkout directory. The default local env file points them at
`%USERPROFILE%\.foreverlove-chat\storage`, so `actions/checkout` cannot delete
user uploads during CI deploys. The website container also proxies `/avatar/*`
and `/chat-files/*` to the API container, so media files still load when those
paths are routed to the website service by a tunnel or reverse proxy.

The script builds both images, starts Docker Compose, waits for health checks,
and prints the URLs to use from the website and Flutter.

Before starting the new Docker Compose deployment, the script backs up the
current PostgreSQL database when an existing PostgreSQL container is present.
Backups are stored in
`%USERPROFILE%\.foreverlove-chat\backups` by default. The retention policy keeps
at most two backups per day and only the latest two calendar days.

Default endpoints:

- Website: `http://<LAN-IP>:17102`
- API: `http://<LAN-IP>:17101`
- API health: `http://localhost:17101/health`
- Version: `http://localhost:17101/api/system/version`

For a public domain or router-forwarded address, set these before deploying:

```powershell
$env:WEB_PUBLIC_URL = "http://your-domain-or-public-ip:17102"
$env:API_PUBLIC_URL = "http://your-domain-or-public-ip:17101"
$env:SIGNALR_PUBLIC_URL = "http://your-domain-or-public-ip:17101/videocallhub"
.\scripts\deploy-local.ps1
```

For Flutter builds, use:

```powershell
flutter run `
  --dart-define=API_BASE_URL=http://your-domain-or-public-ip:17101/api `
  --dart-define=SIGNALR_HUB_URL=http://your-domain-or-public-ip:17101/videocallhub
```

Opening the ports to the public internet still requires Windows Firewall,
router/NAT forwarding, or a reverse proxy/tunnel outside this repository.

## Version control

`VERSION` is the base SemVer version. Local deploys append a local build suffix.
GitHub Actions deploys append the run number and short commit SHA:

```text
1.0.0+<github-run-number>.<short-sha>
```

The resolved version is passed to:

- API image labels and `/api/system/version`
- Website image labels and `APP_CONFIG.VERSION`
- Docker image tags, sanitized for Docker tag rules

## GitHub Actions CI/CD

The workflow `.github/workflows/deploy-local-docker.yml` runs on pushes to
`main` and on manual `workflow_dispatch`. Because GitHub-hosted runners cannot
access Docker Desktop on this computer, the workflow requires a self-hosted
Windows runner registered to this repository with the label `local-docker`.

Recommended GitHub repository settings:

- Secrets: `JWT_SECRET`, `POSTGRES_PASSWORD`, `QQ_CLIENT_ID`, `QQ_CLIENT_SECRET`,
  `EMAIL_PASSWORD`
- Variables: `API_PUBLIC_URL`, `WEB_PUBLIC_URL`, `SIGNALR_PUBLIC_URL`, `QQ_REDIRECT_URI`,
  `ADMIN_EMAILS`, `VITE_ADMIN_EMAILS`, `EMAIL_USERNAME`, `EMAIL_FROM_EMAIL`,
  `EMAIL_PASSWORD_RESET_BASE_URL`
- Optional variables: `POSTGRES_PORT`, `API_PORT`, `WEB_PORT`, `EXTRA_CORS_ORIGIN`,
  `QQ_ALLOW_MOCK_LOGIN`, `EMAIL_SMTP_HOST`, `EMAIL_SMTP_PORT`, `EMAIL_ENABLE_SSL`,
  `EMAIL_FROM_NAME`, `EMAIL_PASSWORD_RESET_TOKEN_MINUTES`, `SWAGGER_ENABLED`,
  `USE_HTTPS_REDIRECTION`, `POSTGRES_CONTAINER`, `POSTGRES_BACKUP_ENABLED`,
  `POSTGRES_BACKUP_DIR`, `POSTGRES_BACKUP_RETENTION_DAYS`,
  `POSTGRES_BACKUP_MAX_PER_DAY`

If secrets are not configured, `scripts/deploy-local.ps1` uses the shared local
env file on the self-hosted runner machine.

For the local self-hosted deployment, keep QQ OAuth values in the shared local
env file instead of committed appsettings files:

```text
%USERPROFILE%\.foreverlove-chat\foreverlove-chat.env
```

Use ASP.NET Core environment variable names:

```dotenv
QQ__ClientId=QQ_APP_ID
QQ__ClientSecret=QQ_APP_KEY
QQ__RedirectUri=https://chat.wangbank.top/qq-callback
QQ__AllowMockLogin=false
API_LOGS_DIR=C:\Users\YOUR_USER\.foreverlove-chat\storage\logs
API_AVATAR_DIR=C:\Users\YOUR_USER\.foreverlove-chat\storage\avatar
API_CHAT_FILES_DIR=C:\Users\YOUR_USER\.foreverlove-chat\storage\chat-files
ADMIN_EMAILS=1224327326@qq.com
VITE_ADMIN_EMAILS=1224327326@qq.com
Email__SmtpHost=smtp.qq.com
Email__SmtpPort=587
Email__EnableSsl=true
Email__Username=1224327326@qq.com
Email__Password=QQ_MAIL_AUTHORIZATION_CODE
Email__FromEmail=1224327326@qq.com
Email__FromName=Forever Love
Email__PasswordResetBaseUrl=https://chat.wangbank.top/reset-password
Email__PasswordResetTokenMinutes=30
POSTGRES_BACKUP_ENABLED=true
POSTGRES_BACKUP_DIR=C:\Users\YOUR_USER\.foreverlove-chat\backups
POSTGRES_BACKUP_RETENTION_DAYS=2
POSTGRES_BACKUP_MAX_PER_DAY=2
```

To restore a `.dump` backup manually, stop the API first, copy the dump into the
PostgreSQL container, and run `pg_restore`:

```powershell
docker compose --project-name foreverlove-chat stop api
docker cp C:\Users\YOUR_USER\.foreverlove-chat\backups\foreverlove_chat-YYYYMMDD-HHMMSS.dump foreverlove-chat-postgres:/tmp/restore.dump
docker exec foreverlove-chat-postgres pg_restore -U postgres -d foreverlove_chat --clean --if-exists /tmp/restore.dump
docker exec foreverlove-chat-postgres rm -f /tmp/restore.dump
docker compose --project-name foreverlove-chat up -d api website
```

## Register the local runner

In GitHub, open:

```text
Settings -> Actions -> Runners -> New self-hosted runner -> Windows x64
```

Copy the generated registration token from the configure command, then run:

```powershell
.\scripts\register-github-runner.ps1 -Token "TOKEN_FROM_GITHUB" -Start
```

This creates a separate runner in `%USERPROFILE%\actions-runner-chat`, leaving
any existing runner directories untouched. Keep the runner running for automatic
deployments, or install it as a service from the runner directory using the
current GitHub runner instructions shown on the GitHub setup page.
