# Forever Love Chat - 视频通话应用

一个基于 Flutter 和 ASP.NET Core 的实时视频通话应用，支持一对一视频通话和群组会议功能。

## 📱 项目架构

```
chat/
├── flutter_client/          # 📱 Flutter 客户端
│   ├── lib/                 #   Dart 源代码
│   │   ├── main.dart        #   应用入口
│   │   ├── user_profile_page.dart  # 用户信息页面
│   │   └── contact_pages.dart      # 联系人页面
│   ├── assets/              #   资源文件（头像等）
│   ├── android/             #   Android 配置
│   ├── ios/                 #   iOS 配置
│   └── pubspec.yaml         #   依赖配置
└── backend_new/             # 🔧 C# 后端 API
    ├── Models/              #   数据模型
    ├── Data/                #   数据库上下文
    ├── Services/            #   业务逻辑
    ├── Controllers/         #   API 控制器
    ├── Hubs/                #   SignalR Hub (WebRTC信令)
    └── Program.cs           #   应用入口
```

## 🚀 快速开始

### 1. 启动后端服务

```bash
cd backend_new
chmod +x start.sh
./start.sh
```

后端将在 `https://localhost:7000` 启动

### 2. 启动Flutter应用

```bash
cd flutter_client
flutter pub get
flutter run
```

## 🛠️ 技术栈

### 前端 (Flutter)
- **Flutter** 3.x - 跨平台UI框架
- **Dart** - 编程语言
- **flutter_webrtc** - WebRTC支持
- **signalr_netcore** - SignalR客户端

### 后端 (C# .NET)
- **ASP.NET Core 8.0** - Web API框架
- **Entity Framework Core** - ORM
- **SQLite** - 轻量级数据库
- **SignalR** - 实时通信
- **JWT** - 身份验证

### 实时通信
- **WebRTC** - 点对点视频通话
- **SignalR** - 信令服务器
- **STUN/TURN** - NAT穿透

## 📊 功能特性

### ✅ 已实现功能
- 👤 用户注册/登录系统
- 📞 一对一视频通话
- 🔊 音频通话
- 👥 联系人管理
- 📋 通话记录
- 🏠 群组会议室
- 🔄 实时在线状态

### 🚧 开发中功能
- 📷 头像上传
- 💬 文字聊天
- 🔔 推送通知
- 📹 通话录制
- 🖥️ 屏幕共享

## 🗄️ 数据库设计

### 主要数据表
- **Users** - 用户信息 (用户名、邮箱、密码等)
- **Contacts** - 联系人关系
- **CallHistory** - 通话记录
- **Rooms** - 会议室信息
- **RoomParticipants** - 会议室参与者

## 🔧 开发环境配置

### 环境要求
- **.NET 8.0 SDK**
- **Flutter SDK** (>=3.0.0)
- **Dart SDK** (>=3.0.0)
- **Android Studio** (Android开发)
- **Xcode** (iOS开发，仅macOS)

### IDE推荐
- **VS Code** + Dart/Flutter扩展
- **Android Studio** + Flutter插件
- **Visual Studio 2022** (后端开发)

## 📱 支持平台

### Flutter客户端
- ✅ **Android** (API 21+)
- ✅ **iOS** (iOS 11.0+)
- ✅ **Web** (Chrome, Safari, Firefox)
- 🚧 **macOS** (开发中)
- 🚧 **Windows** (开发中)

### 后端API
- ✅ **Windows**
- ✅ **macOS**
- ✅ **Linux**

## 🔒 安全特性

- 🔐 **JWT身份验证** - 安全的用户认证
- 🔑 **BCrypt密码加密** - 密码安全存储
- 🛡️ **CORS配置** - 跨域请求保护
- 🔒 **HTTPS支持** - 数据传输加密

## 📖 API文档

启动后端服务后，访问：
- **Swagger UI**: `https://localhost:7000/swagger`
- **API基础路径**: `https://localhost:7000/api`
- **SignalR Hub**: `https://localhost:7000/videocallhub`

### 主要API端点
```
POST /api/auth/register     # 用户注册
POST /api/auth/login        # 用户登录
GET  /api/contacts          # 获取联系人
POST /api/contacts          # 添加联系人
GET  /api/calls/history     # 通话记录
POST /api/calls/rooms       # 创建会议室
```

## 🧪 测试账号

系统自动创建的测试账号：
- **用户1**: `testuser1` / `password123`
- **用户2**: `testuser2` / `password123`

## 🔄 WebRTC 通话流程

```mermaid
sequenceDiagram
    participant A as 用户A
    participant S as SignalR服务器
    participant B as 用户B
    
    A->>S: 发起通话请求
    S->>B: 转发通话邀请
    B->>S: 接受通话
    S->>A: 通知通话被接受
    
    A->>S: 发送WebRTC Offer
    S->>B: 转发Offer
    B->>S: 发送WebRTC Answer
    S->>A: 转发Answer
    
    A<-->B: P2P视频通话建立
```

## 📝 开发日志

### v1.0.0 (当前版本)
- ✅ 基础用户系统
- ✅ 视频通话功能
- ✅ SQLite数据库集成
- ✅ SignalR实时通信

### v1.1.0 (计划中)
- 🚧 文件上传功能
- 🚧 推送通知
- 🚧 界面优化

## 🚀 部署指南

### 开发环境
```bash
# 后端
cd backend_new
dotnet run --environment Development

# 前端
cd flutter_client
flutter run -d chrome  # Web
flutter run -d android # Android
```

### 生产环境
```bash
# 后端
cd backend_new
dotnet publish -c Release
# 部署到云服务器

# 前端
cd flutter_client
flutter build web      # Web版本
flutter build apk      # Android APK
flutter build ipa      # iOS (需要证书)
```

## 🤝 贡献指南

1. Fork 本项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 📞 联系我们

- **项目作者**: WangBank
- **GitHub**: [https://github.com/WangBank](https://github.com/WangBank)

---

**Happy Coding!** 💖
