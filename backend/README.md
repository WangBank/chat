# Forever Love Chat Backend

后端是基于 ASP.NET Core 的即时通讯 API 服务，提供用户认证、联系人、聊天、通话、管理员接口和 SignalR WebRTC 信令。

## 技术栈

- .NET 10 / C# latest
- ASP.NET Core Web API
- Entity Framework Core 10
- Npgsql / PostgreSQL
- SignalR
- JWT Bearer
- BCrypt.Net-Next
- Serilog
- Swashbuckle / OpenAPI

## 本地数据库

开发环境使用 Docker PostgreSQL：

```bash
docker run --name foreverlove-chat-postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=foreverlove_chat_dev \
  -p 17132:5432 \
  -d postgres:latest
```

默认连接串位于 `appsettings.Development.json`：

```text
Host=localhost;Port=17132;Database=foreverlove_chat_dev;Username=postgres;Password=postgres
```

生产默认连接串位于 `appsettings.json`，也可以通过环境变量 `ConnectionStrings__DefaultConnection` 覆盖。

## 开发命令

```bash
dotnet restore
dotnet build
dotnet ef database update
ASPNETCORE_ENVIRONMENT=Development dotnet run
```

服务默认监听 `http://localhost:17101`，Swagger UI 位于 `http://localhost:17101/swagger`。

## 功能模块

- 认证和资料：注册后自动登录、用户名/邮箱登录、密码修改、邮件重置密码、QQ 登录/绑定、QQ dev-login、头像上传、签名、性别、生日年份、国家、省份和城市资料。
- 好友和联系人：用户搜索、好友申请、好友通知、同意/拒绝、清理已处理通知、删除联系人、屏蔽联系人、修改联系人备注。
- 单聊消息：文本、图片、文件、语音类型、聊天文件上传、消息引用快照、已读标记、未读列表、聊天历史和聊天列表。
- 群聊消息：创建群聊、群成员、群公告/备注、群消息历史、群消息发送和群消息引用。
- 收藏：支持收藏聊天、媒体、文件、链接和笔记，提供类型筛选、重复校验和删除。
- 管理后台：管理员查看在线用户、分页用户列表、创建用户、编辑用户和重置用户密码。
- 安全防护：敏感词过滤、上传文件类型限制、外部 URL 校验、存储文件路径校验、JWT 鉴权和基础响应安全头。

## QQ 登录配置

QQ 登录配置位于 `QQ` 配置段，也可以通过环境变量覆盖：

```json
"QQ": {
  "ClientId": "QQ互联 APP_ID",
  "ClientSecret": "QQ互联 APP_KEY",
  "RedirectUri": "https://chat.wangbank.top/qq-callback",
  "AllowMockLogin": false
}
```

对应环境变量：

```bash
QQ__ClientId=QQ_APP_ID
QQ__ClientSecret=QQ_APP_KEY
QQ__RedirectUri=https://chat.wangbank.top/qq-callback
QQ__AllowMockLogin=false
```

真实 QQ OAuth 登录会同步 `nickname`、头像、性别、国家、省份、城市和 `year` 年份。QQ 互联 `get_user_info` 标准接口不返回完整生日和个性签名；后端会接收 `signature` 字段，但只有接口或 dev-login 实际返回时才会写入。

## QQ 邮箱发信配置

忘记密码邮件配置和 QQ 登录配置一样放在 `appsettings*.json` 的顶层配置段，也可以用环境变量覆盖：

```json
"Email": {
  "SmtpHost": "smtp.qq.com",
  "SmtpPort": 587,
  "EnableSsl": true,
  "Username": "your-email@qq.com",
  "Password": "QQ邮箱授权码",
  "FromEmail": "your-email@qq.com",
  "FromName": "Forever Love",
  "PasswordResetBaseUrl": "http://localhost:5173/reset-password",
  "PasswordResetTokenMinutes": 30
}
```

对应环境变量示例：

```bash
Email__Username=your-email@qq.com
Email__Password=your-qq-mail-authorization-code
Email__FromEmail=your-email@qq.com
Email__PasswordResetBaseUrl=http://localhost:5173/reset-password
Email__PasswordResetTokenMinutes=30
```

`Email:Username` 填完整 QQ 邮箱地址，通常和 `Email:FromEmail` 一致；不要填昵称、应用名或 QQ 互联里的名称。`Email:Password` 使用 QQ 邮箱生成的授权码，不是 QQ 登录密码。

QQ 邮箱授权码配置位置：PC 浏览器登录 QQ 邮箱网页版，点击右上角头像进入 `设置` -> `账号与安全` -> `安全设置`，在 `POP3/IMAP/SMTP/Exchange/CardDAV/CalDAV服务` 区域开启服务，然后点击 `生成授权码`。官方帮助页：https://help.mail.qq.com/detail/106/985

## Docker 一键部署

仓库根目录提供 API Docker 部署脚本，会自动创建 Docker network、确认 PostgreSQL 容器、构建 API 镜像、停止旧 API 容器或占用 API 端口的本地服务，并启动新容器：

```bash
./deploy-api-docker.sh
```

默认访问地址：

```text
http://localhost:17101/swagger
```

常用覆盖项：

```bash
API_PORT=17103 ./deploy-api-docker.sh
API_IMAGE=foreverlove-chat-api:prod API_CONTAINER=foreverlove-chat-api-prod ./deploy-api-docker.sh
```

如果使用外部 PostgreSQL，不让脚本管理数据库容器：

```bash
API_ENVIRONMENT=Production \
POSTGRES_HOST=host.docker.internal \
POSTGRES_CONTAINER_PORT=17132 \
SKIP_POSTGRES=1 \
./deploy-api-docker.sh
```

## 数据库迁移

当前 provider 是 PostgreSQL：

```bash
dotnet ef migrations add <MigrationName>
dotnet ef database update
```

应用启动时会执行 `Database.MigrateAsync()`，首次启动会自动应用未执行的 migration，并创建默认 `admin` 账号记录。

完整 Docker Compose 发布由仓库根目录的 `scripts/deploy-local.ps1` 和 GitHub Actions self-hosted runner 执行。发布脚本会在 `docker compose up` 前对已有 PostgreSQL 容器执行一次 `pg_dump -Fc` 备份，默认保存到 `%USERPROFILE%\.foreverlove-chat\backups`，按最近两天、每天最多两个备份保留。恢复命令见仓库根目录 [DEPLOYMENT.md](../DEPLOYMENT.md)。

## API 摘要

- `POST /api/auth/register` - 用户注册
- `POST /api/auth/login` - 用户登录
- `GET /api/auth/qq/login-url` - 生成 QQ 授权地址
- `POST /api/auth/qq/login` - QQ OAuth 登录
- `POST /api/auth/qq/bind` - 当前账号绑定 QQ
- `POST /api/auth/qq/dev-login` - 受控 QQ 测试登录，需开启 `QQ:AllowMockLogin`
- `POST /api/auth/qq/dev-bind` - 受控 QQ 测试绑定，需开启 `QQ:AllowMockLogin`
- `POST /api/auth/change-password` - 修改密码
- `POST /api/auth/forgot-password` - 发送密码重置邮件
- `POST /api/auth/reset-password` - 使用邮件 token 重置密码
- `GET /api/auth/profile` - 获取用户信息
- `PUT /api/auth/profile` - 更新用户资料
- `POST /api/auth/upload-avatar` - 上传头像
- `GET /api/auth/search-users` - 搜索可添加用户
- `GET /api/contacts` - 获取联系人列表
- `GET /api/contacts/search` - 搜索联系人
- `POST /api/contacts` - 兼容旧客户端，发送好友申请，不直接添加联系人
- `GET /api/contacts/friend-requests` - 获取好友申请
- `POST /api/contacts/friend-requests` - 发送好友申请
- `PATCH /api/contacts/friend-requests/{requestId}` - 同意或拒绝好友申请
- `DELETE /api/contacts/{id}` - 删除联系人
- `PATCH /api/contacts/{id}/block` - 屏蔽或取消屏蔽联系人
- `PATCH /api/contacts/{id}/display-name` - 修改联系人备注
- `POST /api/chat/upload` - 上传聊天图片或文件
- `POST /api/chat/send` - 发送消息
- `GET /api/chat/history/{contactId}` - 获取聊天记录
- `PATCH /api/chat/messages/{messageId}/read` - 标记消息已读
- `GET /api/chat/unread` - 获取未读消息
- `GET /api/chat/chat-history` - 获取聊天列表和最近历史
- `DELETE /api/chat/chat-history/{contactId}` - 删除指定聊天历史
- `GET /api/groups` - 获取群聊列表
- `POST /api/groups` - 创建群聊
- `GET /api/groups/{groupId}/messages` - 获取群聊消息
- `POST /api/groups/{groupId}/messages` - 发送群聊消息
- `GET /api/favorites` - 获取收藏列表
- `POST /api/favorites` - 新增收藏
- `PUT /api/favorites/{favoriteId}` - 更新收藏笔记
- `DELETE /api/favorites/{favoriteId}` - 删除收藏
- `GET /api/calls/history` - 获取通话记录
- `POST /api/calls/rooms` - 创建群组通话房间
- `GET /api/admin/online-users` - 管理员查看在线用户
- `GET /api/admin/users` - 管理员查看用户
- `POST /api/admin/users` - 管理员创建用户
- `PUT /api/admin/users/{userId}` - 管理员编辑用户
- `POST /api/admin/change-user-password` - 管理员修改用户密码

## 日志

Serilog 同时输出控制台和文件：

- 日志目录：`logs/`
- 文件格式：`videocall-YYYYMMDD.log`
- 滚动策略：每天一个文件
- 保留数量：30 个文件

常用命令：

```bash
tail -f logs/videocall-*.log
grep "ERR" logs/videocall-*.log
```

## 功能校验

基础 smoke test：

```bash
curl -s http://localhost:17101/swagger/v1/swagger.json
curl -s -X POST http://localhost:17101/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"username":"demo","email":"demo@example.com","password":"Password123!"}'
```

完整进度和最新验证记录见 [PROGRESS.md](PROGRESS.md)。
