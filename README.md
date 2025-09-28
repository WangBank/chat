# Forever Love Chat - 视频通话应用

一个基于 Flutter 和 ASP.NET Core 的实时视频通话应用，支持一对一视频通话和群组会议功能。

## 📂 项目结构

```
chat/
├── flutter_client/          # 📱 Flutter 客户端项目
│   ├── lib/                 #   Dart 源代码
│   ├── assets/              #   资源文件（头像等）
│   ├── android/             #   Android 平台配置
│   ├── ios/                 #   iOS 平台配置
│   ├── web/                 #   Web 平台配置
│   └── pubspec.yaml         #   Flutter 依赖配置
├── backend/                 # 🔧 C# 后端 API 项目
│   ├── Models/              #   数据模型
│   ├── Data/                #   数据库上下文 (SQLite)
│   ├── Services/            #   业务逻辑服务
│   ├── Controllers/         #   API 控制器
│   ├── Hubs/                #   SignalR Hub (WebRTC信令)
│   ├── Program.cs           #   应用入口
│   ├── appsettings.json     #   配置文件
│   └── start.sh             #   启动脚本
├── .github/                 #   GitHub 配置
├── PROJECT_README.md        #   详细项目说明
└── RESTRUCTURE_COMPLETE.md  #   重构说明
```

## 🚀 快速开始

### 1. 启动后端服务 (C# API)

```bash
cd backend
chmod +x start.sh
./start.sh
```

后端将在 `https://192.168.124.7:7000` 启动
- **API文档**: `https://192.168.124.7:7000/swagger`
- **SignalR Hub**: `https://192.168.124.7:7000/videocallhub`

### 2. 启动Flutter客户端

```bash
cd flutter_client
flutter pub get
flutter run
```

## 🛠️ 技术栈

### 前端
- **Flutter** 3.x - 跨平台UI框架
- **flutter_webrtc** - WebRTC视频通话
- **signalr_netcore** - 实时通信

### 后端
- **ASP.NET Core 8.0** - Web API框架
- **SQLite** - 轻量级数据库
- **SignalR** - 实时通信
- **JWT** - 身份验证

## 📱 支持平台

- ✅ **Android** (API 21+)
- ✅ **iOS** (iOS 11.0+)
- ✅ **Web** (Chrome, Safari, Firefox)
- ✅ **Windows/macOS/Linux** (后端)

## 🎯 功能特性

### ✅ 已实现
- 👤 用户注册/登录系统
- 📞 一对一视频通话架构
- 🔊 音频通话支持
- 👥 联系人管理
- 📋 通话记录
- 🏠 群组会议室
- 🔄 实时在线状态

### 🚧 开发中
- 💬 文字聊天
- 📷 头像上传
- 🔔 推送通知
- 📹 通话录制

## 🧪 测试账号

系统自动创建的测试账号：
- **用户1**: `testuser1` / `123`
- **用户2**: `testuser2` / `123`

## 📖 详细文档

- 📋 [项目详细说明](PROJECT_README.md)
- 🔄 [重构完成说明](RESTRUCTURE_COMPLETE.md)
- 📱 [Flutter客户端文档](flutter_client/README.md)
- 🔧 [后端API文档](backend/README.md)

## 🗄️ 数据库

使用 SQLite 轻量级数据库：
- **开发环境**: `backend/videocall_dev.db`
- **生产环境**: `backend/videocall.db`

## 🔒 安全特性

- 🔐 JWT身份验证
- 🔑 BCrypt密码加密
- 🛡️ CORS配置
- 🔒 HTTPS支持

## 📞 API端点

```
POST /api/auth/register     # 用户注册
POST /api/auth/login        # 用户登录
GET  /api/contacts          # 获取联系人
POST /api/contacts          # 添加联系人
GET  /api/calls/history     # 通话记录
POST /api/calls/rooms       # 创建会议室
```

## 🚀 部署

### 开发环境
```bash
# 后端
cd backend && dotnet run

# 前端  
cd flutter_client && flutter run
```

### 生产环境
```bash
# 后端
cd backend && dotnet publish -c Release

# 前端
cd flutter_client && flutter build web    # Web版本
cd flutter_client && flutter build apk    # Android APK
```

## 🤝 贡献

1. Fork 本项目
2. 创建功能分支
3. 提交更改
4. 创建 Pull Request

## 📄 许可证

MIT License

---

**Happy Coding!** 💖 **Let's build something amazing together!** 🚀
