# Video Call API - SQLite版本

这是一个基于 ASP.NET Core 8.0 的 WebRTC 视频通话后台 API 服务，使用 SQLite 作为数据库。

## 项目结构

```
chat/
├── flutter_client/          # Flutter 客户端项目
│   ├── lib/                 # Flutter 源代码
│   ├── assets/              # 资源文件
│   ├── android/             # Android 平台配置
│   ├── ios/                 # iOS 平台配置
│   ├── web/                 # Web 平台配置
│   └── pubspec.yaml         # Flutter 依赖配置
├── backend_new/             # C# 后端 API 项目
│   ├── Models/              # 数据模型
│   ├── Data/                # 数据库上下文
│   ├── Services/            # 业务逻辑服务
│   ├── Controllers/         # API 控制器
│   ├── Hubs/                # SignalR Hub
│   ├── Program.cs           # 应用入口
│   ├── appsettings.json     # 配置文件
│   └── VideoCallAPI.csproj  # 项目文件
└── README.md               # 本文档
```

## 数据库配置

### SQLite 优势
- **轻量级**: 无需安装独立的数据库服务器
- **便携性**: 数据库文件可以随项目移动
- **开发友好**: 快速启动，无需配置
- **跨平台**: 支持所有操作系统

### 数据库文件
- 开发环境: `videocall_dev.db`
- 生产环境: `videocall.db`

## 快速开始

### 1. 启动后端服务

```bash
cd backend_new
chmod +x start.sh
./start.sh
```

或者手动启动：

```bash
cd backend_new
dotnet restore
dotnet run
```

### 2. 启动Flutter客户端

```bash
cd flutter_client
flutter pub get
flutter run
```

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

### 通话相关
- `GET /api/calls/history` - 获取通话记录
- `POST /api/calls/rooms` - 创建群组通话房间

## 测试账号

系统会自动创建以下测试账号：
- **用户名**: `testuser1`, **密码**: `123`
- **用户名**: `testuser2`, **密码**: `123`

## Flutter客户端集成

### 1. 添加依赖

在 `flutter_client/pubspec.yaml` 中添加：

```yaml
dependencies:
  flutter:
    sdk: flutter
  signalr_netcore: ^1.3.7
  flutter_webrtc: ^0.9.46
  http: ^1.1.0
  permission_handler: ^11.0.1
```

## 开发特性

### 1. 热重载支持
- 后端支持代码更改时自动重新编译
- Flutter支持热重载

### 2. 自动数据库初始化
- 首次运行时自动创建数据库表
- 自动插入测试数据

### 3. 开发工具
- Swagger API 文档
- Entity Framework 迁移工具
- 详细的日志输出

## 部署说明

### 开发环境
```bash
# 后端
cd backend_new
dotnet run --environment Development

# 前端
cd flutter_client
flutter run -d chrome  # Web版本
flutter run            # 移动端
```

### 生产环境
```bash
# 后端
cd backend
dotnet publish -c Release -o ./release --self-contained false
cd publish
dotnet VideoCallAPI.dll

# 前端
cd flutter_client
flutter build web       # 构建Web版本
flutter build apk       # 构建Android APK
flutter build ios       # 构建iOS (需要macOS)
```

## 数据库管理

### 查看数据库
推荐使用以下工具查看SQLite数据库：
- **DB Browser for SQLite** (图形界面)
- **sqlite3** (命令行)
- **VS Code SQLite扩展**

```bash
# 命令行查看
sqlite3 videocall_dev.db
.tables          # 查看所有表
.schema users    # 查看用户表结构
SELECT * FROM users;  # 查询所有用户
```

### 重置数据库
```bash
cd backend_new
rm videocall_dev.db  # 删除数据库文件
dotnet run           # 重新运行，会自动创建新数据库
```

## 故障排除

### 1. 端口占用
如果7000端口被占用，修改 `appsettings.json`：


### 2. 数据库权限问题
确保应用对数据库文件所在目录有读写权限：
```bash
chmod 755 backend_new/
```

### 3. Flutter依赖问题
```bash
cd flutter_client
flutter clean
flutter pub get
```

## 下一步开发

1. **增强安全性**
   - 实现更强的JWT验证
   - 添加用户权限控制

2. **功能扩展**
   - 文件上传（头像）
   - 推送通知
   - 聊天消息功能

3. **性能优化**
   - 数据库索引优化
   - WebRTC连接池管理

4. **监控和日志**
   - 添加应用性能监控
   - 详细的错误日志

## 技术支持

如遇到问题，请检查：
1. .NET 8.0 SDK 是否正确安装
2. Flutter SDK 是否正确配置
3. 防火墙是否允许相应端口
4. 证书是否正确配置（HTTPS）
ifconfig | grep inet

---

**祝开发顺利！** 🚀
