# Forever Love Chat 发布流程

本文档覆盖 Docker 服务发布、GitHub Actions 自托管部署、Android APK 发布与同步，以及音视频 SFU/TURN 的生产配置。产品能力说明见[功能说明](README.md)。

## 发布前检查

1. 在 `main` 分支确认改动已提交并已推送。
2. 按改动范围运行构建和测试：后端使用 `dotnet build`，Web 使用 `npm run build` 与 `npm run test:contracts`，Flutter 使用 `flutter test` 和 `flutter build apk --debug`。
3. 确认发布主机安装 Docker Desktop/Compose，并已注册带有 `local-docker` 标签的 Windows self-hosted runner。
4. 不要把数据库密码、JWT、QQ App Key、邮箱授权码、签名密钥或 TURN 凭据提交到仓库。

## Docker 服务发布

### 首次发布

在 Windows 发布主机的仓库根目录执行：

```powershell
.\scripts\deploy-local.ps1
```

脚本会：

1. 创建或复用 `%USERPROFILE%\.foreverlove-chat\foreverlove-chat.env`。
2. 创建/复用 PostgreSQL，构建 API 和 Web 镜像，并启动 Docker Compose。
3. 在替换已有 PostgreSQL 容器前执行 `pg_dump -Fc` 备份。
4. 等待健康检查完成并输出网站、API 和 Flutter 使用的地址。

默认地址如下：

| 服务 | 默认地址 |
| --- | --- |
| 网站 | `http://<LAN-IP>:17102` |
| API | `http://<LAN-IP>:17101` |
| API 健康检查 | `http://localhost:17101/health` |
| Swagger | `http://localhost:17101/swagger` |
| 版本信息 | `http://localhost:17101/api/system/version` |

文件上传、日志、下载文件和备份默认保存在 `%USERPROFILE%\.foreverlove-chat\storage` 与 `%USERPROFILE%\.foreverlove-chat\backups`，不放在 Actions checkout 中，避免部署检出时被删除。

### 公网地址

使用域名、反向代理或路由器端口映射时，在受保护环境文件中配置：

```dotenv
WEB_PUBLIC_URL=https://chat.example.com
API_PUBLIC_URL=https://chat.example.com
SIGNALR_PUBLIC_URL=https://chat.example.com/videocallhub
```

外网访问还需要由 Windows 防火墙、云安全组、路由器或反向代理放行 HTTP/HTTPS。Web 端会代理 `/avatar/*` 和 `/chat-files/*` 到 API，保证这些媒体路径经过网站域名时仍能正常访问。

### 关键变量

在共享环境文件或 GitHub Actions 的变量/密钥中配置。密钥应使用 GitHub Secrets 或发布主机的受保护环境文件：

| 分类 | 变量 |
| --- | --- |
| 必需密钥 | `JWT_SECRET`、`POSTGRES_PASSWORD` |
| QQ 登录 | `QQ__ClientId`、`QQ__ClientSecret`、`QQ__RedirectUri`、`QQ__AllowMockLogin` |
| 邮件 | `Email__SmtpHost`、`Email__SmtpPort`、`Email__EnableSsl`、`Email__Username`、`Email__Password`、`Email__FromEmail`、`Email__FromName`、`Email__PasswordResetBaseUrl` |
| 管理员与 CORS | `ADMIN_EMAILS`、`VITE_ADMIN_EMAILS`、`EXTRA_CORS_ORIGIN` |
| 存储与备份 | `API_LOGS_DIR`、`API_AVATAR_DIR`、`API_CHAT_FILES_DIR`、`POSTGRES_BACKUP_*` |
| 地址与端口 | `API_PORT`、`WEB_PORT`、`API_PUBLIC_URL`、`WEB_PUBLIC_URL`、`SIGNALR_PUBLIC_URL` |

QQ 邮箱 `Email__Password` 使用邮箱授权码，不是 QQ 登录密码。

### 数据库恢复

先停止 API，确认目标备份文件后再恢复：

```powershell
docker compose --project-name foreverlove-chat stop api
docker cp C:\Users\YOUR_USER\.foreverlove-chat\backups\foreverlove_chat-YYYYMMDD-HHMMSS.dump foreverlove-chat-postgres:/tmp/restore.dump
docker exec foreverlove-chat-postgres pg_restore -U postgres -d foreverlove_chat --clean --if-exists /tmp/restore.dump
docker exec foreverlove-chat-postgres rm -f /tmp/restore.dump
docker compose --project-name foreverlove-chat up -d api website
```

## 自动部署

`.github/workflows/deploy-local-docker.yml` 会在推送 `main` 或手工运行时，使用标签为 `self-hosted, Windows, X64, local-docker` 的 runner 执行 `scripts/deploy-local.ps1`。

发布版本格式为：

```text
<VERSION>+<GitHub Run Number>.<短提交 SHA>
```

该版本会写入 API `/api/system/version`、网站运行时配置和镜像标签。部署完成后检查 Actions summary、健康检查、网站登录、消息收发和关键媒体路径。

### 注册自托管 runner

在 GitHub 仓库的 `Settings -> Actions -> Runners -> New self-hosted runner -> Windows x64` 获取注册 token，然后在发布主机执行：

```powershell
.\scripts\register-github-runner.ps1 -Token "TOKEN_FROM_GITHUB" -Start
```

该脚本使用 `%USERPROFILE%\actions-runner-chat`，不会覆盖其他 runner 目录。

## Android APK 发布

### 前置配置

在 GitHub Secrets 配置以下签名变量：

```text
ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
```

可选 GitHub Variables：

```text
ANDROID_API_BASE_URL
ANDROID_SIGNALR_HUB_URL
ANDROID_MIN_SUPPORTED_VERSION_CODE
ANDROID_UPDATE_MANDATORY
```

### 一键发布

在干净的 `main` 分支执行：

```bash
./scripts/release-android-apk.sh --yes
```

脚本会递增 `flutter_client/pubspec.yaml` 的版本和 build number，提交并推送版本变更，运行本地 Debug APK 预检查，然后手动触发 `Android Release APK` 工作流。工作流构建签名 APK、校验非 debug 签名、生成 SHA256 和 `android-version.json`，最后创建 GitHub Release。

常用命令：

```bash
./scripts/release-android-apk.sh --dry-run
./scripts/release-android-apk.sh --bump minor --yes
./scripts/release-android-apk.sh --version 1.2.0 --version-code 12 --yes
```

注意：推送到 `main` 的 Android 工作流只构建 artifact；只有 `workflow_dispatch` 才会发布 GitHub Release。一键脚本会完成两步，因此不要只依赖推送构建作为正式发布。

发布后确认：

1. GitHub Release 中包含 `LoveChat-Android.apk` 与 `android-version.json`。
2. `apksigner` 验证输出不是 Android Debug 证书。
3. APK SHA256 与清单中的 `sha256` 一致。
4. 清单中的版本号与 `pubspec.yaml` 的版本一致。

## Android 国内下载同步

GitHub Release 是签名 APK 的唯一构建来源。`Sync Android APK` 工作流在 Android 发布成功后、每天定时或手工触发时，在发布主机运行 `scripts/sync-android-release.ps1`：

1. 下载最新 Release 的 APK 和清单。
2. 校验文件大小和 SHA256。
3. 写入 `WEB_DOWNLOADS_DIR`（默认 `%USERPROFILE%\.foreverlove-chat\storage\downloads`）。
4. 改写清单的 `apkUrl`，使其指向产品域名。

网站容器把该目录挂载为 `/app/downloads`，并提供：

```text
https://chat.wangbank.top/download/android
https://chat.wangbank.top/download/android-version.json
```

下载路由支持附件下载、ETag、Range 续传；同步文件缺失时会 302 回退到 GitHub Release。Flutter 更新器按 `apkUrl`、`apkFallbackUrl` 和 `mirrors` 顺序重试下载。

可选变量：`WEB_DOWNLOADS_DIR`、`APK_PUBLIC_BASE_URL`、`APK_ASSET_MIRROR_PREFIX`。同步后验证：

```powershell
curl.exe -I https://chat.wangbank.top/download/android
curl.exe -s https://chat.wangbank.top/download/android-version.json
```

## LiveKit 音视频服务

通话媒体由 `livekit` 容器承载；API 只校验通话状态并签发短期房间令牌，SignalR 只传递来电、接听和结束事件。不要配置已移除的 `WEBRTC_SFU_*`、`WEBRTC_TURN_*` 或旧 `/api/system/webrtc-config` 接口。

### 公网配置

在发布主机的受保护环境文件中配置。`LIVEKIT_NODE_IP` 必须是这台主机能被手机客户端访问的公网 IPv4，不能填 Docker 容器地址、`127.0.0.1` 或内网地址。API 使用的密钥必须与 LiveKit 使用的密钥完全一致。

```dotenv
LIVEKIT_PUBLIC_URL=wss://media.example.com
LIVEKIT_API_KEY=replace-with-a-livekit-api-key
LIVEKIT_API_SECRET=replace-with-at-least-32-random-characters
LIVEKIT_NODE_IP=PUBLIC_IPV4_OF_THIS_HOST
LIVEKIT_USE_EXTERNAL_IP=false
LIVEKIT_BIND_HOST=0.0.0.0
LIVEKIT_PORT=7880
LIVEKIT_RTC_TCP_PORT=7881
LIVEKIT_RTC_PORT_MIN=50000
LIVEKIT_RTC_PORT_MAX=50100
```

`media.example.com` 需要解析到该公网 IP。网站走 HTTPS 时，`LIVEKIT_PUBLIC_URL` 必须为 `wss://`；通过反向代理终止 TLS 时，代理必须把 WebSocket 和 HTTP 请求转发到 `livekit:7880`。媒体 UDP 不经过 HTTP 反向代理。

在 Windows 防火墙、云安全组和路由器/NAT 上放行并映射：TCP `7880`（或反向代理入口）、TCP `7881`、UDP `50000-50100`。Docker 的 LiveKit 端口映射必须绑定到 `0.0.0.0`，不能只绑定 `127.0.0.1`。修改公网 IP、端口范围或密钥后重新创建 `livekit` 容器：

```powershell
docker compose up -d --force-recreate livekit api website
```

没有固定公网 IP 时可设置 `LIVEKIT_USE_EXTERNAL_IP=true` 让 LiveKit 通过 STUN 探测地址，并留空 `LIVEKIT_NODE_IP`；有固定公网 IP 时优先显式设置 `LIVEKIT_NODE_IP`，结果更可预测。

### 受限网络和 TURN

LiveKit 的 UDP 和 TCP 候选可以覆盖大多数网络。若运营商网络或企业网络仍阻断媒体，按 LiveKit 的 TURN 文档为 LiveKit 配置内置 TURN 或独立 coturn；TURN 参数属于 LiveKit 的服务器配置，不再由 API 下发。TURN 域名必须直连公网 IP，不能置于仅支持 HTTP 的 CDN 代理之后，并应额外放行其监听与 relay 端口范围。

### 发布后验证

1. 检查 `docker compose ps`，确认 `livekit`、`api` 和 `website` 均已运行；检查 `docker logs <livekit-container>`，确认 `nodeIP` 是服务器公网 IPv4，不能是 Docker `172.*` 地址。
2. 使用两台真实设备，分别在 Wi-Fi 和移动数据网络完成一次双向视频通话及一次双向语音通话。
3. 确认接听前 `/api/calls/{callId}/livekit-token` 返回 `409`，接听后双方取得同一房间名的令牌，旁观账号返回 `404`。
4. 结束后检查通话历史包含该 UUID、结束时间与正确状态；日志不得记录 LiveKit 令牌、API Secret 或媒体内容。
