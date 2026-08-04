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

The script builds both images, starts Docker Compose, waits for health checks,
and prints the URLs to use from the website and Flutter.

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

- Secrets: `JWT_SECRET`, `POSTGRES_PASSWORD`, `QQ_CLIENT_ID`, `QQ_CLIENT_SECRET`
- Variables: `API_PUBLIC_URL`, `WEB_PUBLIC_URL`, `SIGNALR_PUBLIC_URL`, `QQ_REDIRECT_URI`,
  `ADMIN_EMAILS`, `VITE_ADMIN_EMAILS`
- Optional variables: `POSTGRES_PORT`, `API_PORT`, `WEB_PORT`, `EXTRA_CORS_ORIGIN`,
  `QQ_ALLOW_MOCK_LOGIN`, `SWAGGER_ENABLED`, `USE_HTTPS_REDIRECTION`

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
ADMIN_EMAILS=1224327326@qq.com
VITE_ADMIN_EMAILS=1224327326@qq.com
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
