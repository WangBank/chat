# Forever Love Chat

Forever Love Chat 是一个即时通讯项目，包含 ASP.NET Core 后端、React Web 客户端和 Flutter 移动端客户端。核心功能包括账号注册登录、联系人管理、即时消息、语音通话、视频通话、通话记录、群组房间和管理员后台。

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

## 主要 API

- `POST /api/auth/register` - 用户注册
- `POST /api/auth/login` - 用户登录
- `GET /api/auth/profile` - 获取用户信息
- `GET /api/contacts` - 获取联系人
- `POST /api/contacts` - 兼容旧客户端，发送好友申请，不直接添加联系人
- `POST /api/contacts/friend-requests` - 发送好友申请
- `PATCH /api/contacts/friend-requests/{requestId}` - 同意或拒绝好友申请
- `POST /api/chat/send` - 发送消息
- `GET /api/chat/history/{contactId}` - 获取聊天记录
- `GET /api/calls/history` - 获取通话记录
- `POST /api/calls/rooms` - 创建群组通话房间

## 子项目文档

- [后端说明](backend/README.md)
- [后端进度](backend/PROGRESS.md)
- [Web 客户端说明](website/README.md)
- [Web 客户端进度](website/PROGRESS.md)
- [Flutter 客户端说明](flutter_client/README.md)
- [Flutter 客户端进度](flutter_client/PROGRESS.md)
