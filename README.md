# Forever Love Chat

Forever Love Chat 是一个即时通讯项目，包含 ASP.NET Core 后端、React Web 客户端和 Flutter 移动端客户端。核心功能包括账号注册登录、QQ 登录/绑定、联系人和好友申请、即时消息、消息引用、表情/GIF、图片文件发送、群聊、收藏、历史记录、语音通话、视频通话、通话记录、管理员后台和发布前数据库备份。

## 项目结构

```text
chat/
├── backend/          # ASP.NET Core API、SignalR Hub、EF Core 数据访问
├── website/          # React + Vite Web 客户端
├── flutter_client/   # Flutter 移动端客户端
├── README.md         # 项目介绍
└── PROGRESS.md       # 项目进度
```

每个子项目只保留一个 `README.md` 和一个 `PROGRESS.md` 作为项目文档。

## 当前技术栈

### 后端

- .NET 10 / C# latest
- ASP.NET Core Web API
- Entity Framework Core 10 + Npgsql
- PostgreSQL
- SignalR
- JWT + BCrypt
- Serilog
- Swagger/OpenAPI

### Web 客户端

- React 19
- TypeScript 6.0
- Vite 8
- Ant Design 6
- MobX
- Axios
- SignalR Client
- WebRTC

### Flutter 客户端

- Flutter 3.44
- Dart 3.12
- Android Gradle Plugin 9
- Gradle 9
- Kotlin 2.3
- flutter_webrtc
- signalr_netcore
- shared_preferences
- sqflite

## 功能概览

- 账号体系：用户名/邮箱登录、注册后自动登录、忘记密码邮件、QQ OAuth 登录/绑定、受控 QQ dev-login、头像上传、自定义签名、性别、生日年份和地区资料。
- 好友关系：搜索用户、发送好友申请、处理好友通知、清理已处理通知、联系人备注、屏蔽联系人、Web 端本地好友分组维护。
- 聊天能力：单聊和群聊消息、消息引用快照、已读/未读状态、聊天列表、聊天历史、群聊历史、图片和文件上传、表情面板、Fluent UI Animated Emoji GIF 表情库。
- 收藏能力：收藏聊天、媒体、文件、链接和笔记，支持按类型过滤和搜索。
- 实时能力：SignalR 在线状态、心跳保活、语音/视频通话、WebRTC 信令和通话记录。
- 安全能力：JWT + BCrypt、管理员邮箱配置、敏感词过滤、上传文件类型限制、存储路径校验、基础安全响应头。
- 部署能力：Docker Compose 一键部署前后台和 PostgreSQL，GitHub Actions self-hosted runner 发布，发布前自动备份 PostgreSQL 并按保留策略清理旧备份。

## 快速启动

### 一键启动

根目录提供 `start.sh`，会自动确认 PostgreSQL 容器、启动后端，并按参数启动对应客户端：

```bash
./start.sh              # 默认启动后端 + Web
./start.sh web          # 启动后端 + Web
./start.sh android      # 启动后端 + Android
./start.sh ios          # 启动后端 + iOS
./start.sh mobile       # 启动后端 + Android + iOS
./start.sh all          # 启动后端 + Web + Android + iOS
./start.sh web android  # 可组合参数
./start.sh prod android # Android 连接线上生产环境
./start.sh prod ios     # iOS 连接线上生产环境
```

Android 未检测到已连接设备时会自动启动第一台可用 Android AVD；iOS 未指定设备时会自动选择第一台受支持的 iOS 设备。常用参数可通过环境变量覆盖：

```bash
ANDROID_DEVICE=emulator-5554 ./start.sh android
ANDROID_EMULATOR=Pixel_9_Pro_XL_API_35 ./start.sh android
AUTO_START_ANDROID_EMULATOR=0 ./start.sh android
IOS_DEVICE="iPhone 16 Pro" ./start.sh ios
FLUTTER_DEVICE_CONNECTION=attached ./start.sh mobile
FRONTEND_PORT=5174 ./start.sh web
SKIP_INSTALL=1 ./start.sh all
APP_ENV=production ./start.sh android
```

Android 模拟器默认使用 `http://10.0.2.2:17101/api` 访问本机后端，iOS 模拟器默认使用 `http://localhost:17101/api`。真机调试时请用电脑局域网 IP 覆盖：

```bash
ANDROID_API_URL=http://192.168.1.10:17101/api \
ANDROID_SIGNALR_URL=http://192.168.1.10:17101/videocallhub \
./start.sh android
```

线上生产环境地址为 `https://chat.wangbank.top`。手机端连接生产环境时使用：

```bash
./start.sh prod android
./start.sh prod ios
```

等价的显式配置：

```bash
ANDROID_API_URL=https://chat.wangbank.top/api \
ANDROID_SIGNALR_URL=https://chat.wangbank.top/videocallhub \
./start.sh android
```

### 1. PostgreSQL

开发环境默认连接本机 `17132` 端口：

```bash
docker run --name foreverlove-chat-postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=foreverlove_chat_dev \
  -p 17132:5432 \
  -d postgres:latest
```

如果容器已存在：

```bash
docker start foreverlove-chat-postgres
```

### 2. 后端

```bash
cd backend
dotnet restore
dotnet ef database update
ASPNETCORE_ENVIRONMENT=Development dotnet run
```

后端默认监听 `http://localhost:17101`，Swagger 文档在 `http://localhost:17101/swagger`。

### 3. Web 客户端

```bash
cd website
npm install
npm run dev
```

Vite 默认监听 `http://localhost:5173`。

### 4. Flutter 客户端

```bash
cd flutter_client
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=https://chat.wangbank.top/api \
  --dart-define=SIGNALR_HUB_URL=https://chat.wangbank.top/videocallhub
```

Android debug APK：

```bash
flutter build apk --debug
```

Android GitHub Release 一键发布：

```bash
./scripts/release-android-apk.sh --yes
```

脚本会自动把 `flutter_client/pubspec.yaml` 从 `X.Y.Z+N` 提升到 `X.Y.(Z+1)+(N+1)`，提交并推送版本号，然后触发 GitHub Actions 的 `Android Release APK` workflow 发布签名 APK。发布前预览可用：

```bash
./scripts/release-android-apk.sh --dry-run
```

## 主要 API

- `POST /api/auth/register` - 用户注册
- `POST /api/auth/login` - 用户登录
- `GET /api/auth/qq/login-url` - 获取 QQ 授权地址
- `POST /api/auth/qq/login` - QQ 登录
- `POST /api/auth/qq/bind` - 绑定 QQ
- `POST /api/auth/forgot-password` - 发送密码重置邮件
- `POST /api/auth/reset-password` - 使用邮件 token 重置密码
- `GET /api/auth/profile` - 获取用户信息
- `PUT /api/auth/profile` - 更新头像、签名、性别、生日和地区等资料
- `POST /api/auth/upload-avatar` - 上传头像
- `GET /api/contacts` - 获取联系人
- `POST /api/contacts` - 兼容旧客户端，发送好友申请，不直接添加联系人
- `POST /api/contacts/friend-requests` - 发送好友申请
- `PATCH /api/contacts/friend-requests/{requestId}` - 同意或拒绝好友申请
- `PATCH /api/contacts/{contactId}/display-name` - 修改联系人备注
- `POST /api/chat/send` - 发送消息
- `POST /api/chat/upload` - 上传聊天图片或文件
- `GET /api/chat/history/{contactId}` - 获取聊天记录
- `GET /api/chat/chat-history` - 获取聊天列表和最近消息
- `PATCH /api/chat/messages/{messageId}/read` - 标记消息已读
- `GET /api/groups` - 获取群聊列表
- `POST /api/groups` - 创建群聊
- `GET /api/groups/{groupId}/messages` - 获取群聊消息
- `POST /api/groups/{groupId}/messages` - 发送群聊消息
- `GET /api/favorites` - 获取收藏
- `POST /api/favorites` - 新增收藏
- `GET /api/calls/history` - 获取通话记录
- `POST /api/calls/rooms` - 创建群组通话房间

## 子项目文档

- [部署说明](DEPLOYMENT.md)
- [后端说明](backend/README.md)
- [后端进度](backend/PROGRESS.md)
- [Web 客户端说明](website/README.md)
- [Web 客户端进度](website/PROGRESS.md)
- [Flutter 客户端说明](flutter_client/README.md)
- [Flutter 客户端进度](flutter_client/PROGRESS.md)
