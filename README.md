# Forever Love Chat - 即时通讯应用

一个全栈即时通讯应用，支持文字聊天、语音通话和视频通话。采用三端架构：Web客户端、移动端客户端和统一的后端服务。
有任何问题或者需要帮助可以联系QQ: 1224327326

## 📂 项目结构

```
chat/
├── backend/                 # 🔧 后端服务 (ASP.NET Core)
│   ├── Controllers/         #   API 控制器
│   ├── Data/                #   数据库上下文 (SQLite)
│   ├── Hubs/                #   SignalR Hub (WebRTC信令)
│   ├── Models/              #   数据模型
│   ├── Services/            #   业务逻辑服务
│   ├── Program.cs           #   应用入口
│   ├── appsettings.json     #   配置文件
│   └── VideoCallAPI.csproj  #   项目文件
├── website/                 # 🌐 Web客户端 (React)
│   ├── src/
│   │   ├── components/      #   组件
│   │   ├── config/          #   配置文件
│   │   ├── pages/           #   页面
│   │   ├── services/        #   服务层（API、SignalR、WebRTC）
│   │   ├── stores/          #   MobX状态管理
│   │   └── App.tsx          #   主应用组件
│   ├── package.json         #   依赖配置
│   └── vite.config.ts       #   Vite配置
├── flutter_client/          # 📱 移动端客户端 (Flutter)
│   ├── lib/
│   │   ├── config/          #   配置文件
│   │   ├── models/          #   数据模型
│   │   ├── pages/           #   页面
│   │   ├── services/        #   服务层
│   │   └── utils/           #   工具类
│   ├── assets/              #   资源文件（头像等）
│   ├── android/             #   Android 平台配置
│   ├── ios/                 #   iOS 平台配置
│   ├── web/                 #   Web 平台配置
│   └── pubspec.yaml         #   Flutter 依赖配置
└── README.md                #   本文档
```

## 🚀 快速开始

### 1. 启动后端服务

```bash
cd backend
dotnet restore
dotnet run
```

后端服务默认运行在 `http://localhost:7001`

### 2. 启动Web客户端

```bash
cd website
npm install
npm run dev
```

Web客户端默认运行在 `http://localhost:5173`

### 3. 启动Flutter客户端

```bash
cd flutter_client
flutter pub get
flutter run
```

## 🛠️ 技术栈

### 后端
- **ASP.NET Core 10.0** - Web API框架
- **SQLite** - 轻量级数据库
- **SignalR** - 实时通信（WebRTC信令）
- **JWT** - 身份验证
- **BCrypt** - 密码加密
- **Entity Framework Core** - ORM框架

### Web客户端
- **React 19** - UI框架
- **TypeScript** - 类型安全
- **Vite** - 构建工具
- **MobX** - 状态管理
- **Ant Design** - UI组件库
- **SignalR Client** - 实时通信
- **WebRTC** - 音视频通话

### 移动端客户端
- **Flutter 3.x** - 跨平台UI框架
- **flutter_webrtc** - WebRTC视频通话
- **signalr_netcore** - 实时通信
- **sqflite** - 本地数据库
- **Provider** - 状态管理

## 📱 支持平台

- ✅ **Web** - Chrome, Safari, Firefox, Edge
- ✅ **Android** - API 21+
- ✅ **iOS** - iOS 11.0+
- ✅ **Windows/macOS/Linux** - 后端服务

## 🎯 功能特性

### ✅ 已实现
- 👤 用户注册/登录/忘记密码
- 💬 即时消息聊天
- 📞 一对一视频通话（WebRTC）
- 🔊 语音通话（WebRTC）
- 👥 联系人管理（添加、删除、屏蔽、备注）
- 📋 通话记录
- 🏠 群组会议室
- 🔄 实时在线状态
- 👨‍💼 管理员后台（查看在线用户、所有用户）
- 📷 头像上传和管理
- 🔍 用户搜索
- 📱 随机生成账号密码功能
- 🏷️ 版本号显示

## 🧪 测试账号

系统不再自动创建测试账号，请通过注册功能创建新账号进行测试。

**注意**：admin 账户密码请自行修改，建议首次登录后立即更改密码以确保安全。

## 📖 详细文档

- 📱 [Flutter客户端文档](flutter_client/README.md)
- 🔧 [后端API文档](backend/README.md)
- 🌐 [Web客户端文档](website/README.md)
- 🚀 [部署指南](backend/DEPLOYMENT_GUIDE.md)

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

### 认证相关
- `POST /api/auth/register` - 用户注册
- `POST /api/auth/login` - 用户登录
- `POST /api/auth/change-password` - 修改密码
- `GET /api/auth/profile` - 获取用户信息

### 联系人管理
- `GET /api/contacts` - 获取联系人列表
- `POST /api/contacts` - 添加联系人
- `DELETE /api/contacts/{id}` - 删除联系人
- `PATCH /api/contacts/{id}/block` - 屏蔽/取消屏蔽联系人
- `PATCH /api/contacts/{id}/display-name` - 修改联系人备注

### 通话相关
- `GET /api/calls/history` - 获取通话记录
- `POST /api/calls/rooms` - 创建群组通话房间

### 聊天相关
- `POST /api/chat/send` - 发送消息
- `GET /api/chat/history/{userId}` - 获取聊天记录
- `GET /api/chat/unread` - 获取未读消息

## 🚀 部署

### 开发环境

```bash
# 1. 启动后端服务
cd backend
dotnet run

# 2. 启动Web客户端（新终端）
cd website
npm run dev

# 3. 启动Flutter客户端（新终端）
cd flutter_client
flutter run
```

### 生产环境

#### 后端部署
```bash
cd backend
dotnet publish -c Release -o ./publish --self-contained false
cd publish
dotnet VideoCallAPI.dll
```

#### Web客户端部署
```bash
cd website
npm run build
# 将 dist/ 目录部署到 Nginx 或其他 Web 服务器
```

#### Flutter客户端部署
```bash
cd flutter_client
flutter build web       # Web版本
flutter build apk       # Android APK
flutter build ios       # iOS (需要macOS)
```

### Nginx配置（Web客户端）

```bash
sudo chmod 777 /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/chat_website /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
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
