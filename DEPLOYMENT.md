# Forever Love Chat local Docker deployment

This repository deploys the ASP.NET Core API, React website, and PostgreSQL to
local Docker. The API and website ports are published on `0.0.0.0` by default so
LAN devices and externally routed traffic can reach them.

## Local deploy

```powershell
.\scripts\deploy-local.ps1
```

The first run creates an ignored `.env` file with generated local secrets. The
script builds both images, starts Docker Compose, waits for health checks, and
prints the URLs to use from the website and Flutter.

Default endpoints:

- Website: `http://<LAN-IP>:7002`
- API: `http://<LAN-IP>:7001`
- API health: `http://localhost:7001/health`
- Version: `http://localhost:7001/api/system/version`

For a public domain or router-forwarded address, set these before deploying:

```powershell
$env:WEB_PUBLIC_URL = "http://your-domain-or-public-ip:7002"
$env:API_PUBLIC_URL = "http://your-domain-or-public-ip:7001"
$env:SIGNALR_PUBLIC_URL = "http://your-domain-or-public-ip:7001/videocallhub"
.\scripts\deploy-local.ps1
```

For Flutter builds, use:

```powershell
flutter run `
  --dart-define=API_BASE_URL=http://your-domain-or-public-ip:7001/api `
  --dart-define=SIGNALR_HUB_URL=http://your-domain-or-public-ip:7001/videocallhub
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

- Secrets: `JWT_SECRET`, `POSTGRES_PASSWORD`
- Variables: `API_PUBLIC_URL`, `WEB_PUBLIC_URL`, `SIGNALR_PUBLIC_URL`
- Optional variables: `API_PORT`, `WEB_PORT`, `EXTRA_CORS_ORIGIN`,
  `SWAGGER_ENABLED`, `USE_HTTPS_REDIRECTION`

If secrets are not configured, `scripts/deploy-local.ps1` creates local ignored
values in `.env` on the self-hosted runner machine.

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
